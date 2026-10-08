function run_mil(options)
%RUN_MIL Simulate aeb_model with the designed test cases (model in the loop).
%
%   Reads testcases/aeb_testcases.csv and testcases/aeb_sequences.csv,
%   simulates the model, compares with the expected results and writes
%     results/mil_results.csv        one row per simulated sample
%     results/coverage_summary.csv   decision, condition and MC/DC coverage
%
%   The stored results are replayed against the Python reference by
%   tests/test_back_to_back.py, so the model, the Python code and the C code
%   are all checked against the same inputs.
%
%   run_mil(Cases=file, Sequences=file, Results=folder) overrides the inputs
%   and the output folder, for example to run generated check sequences.

arguments
    options.Cases (1, 1) string = ""
    options.Sequences (1, 1) string = ""
    options.Results (1, 1) string = ""
end

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
cases_file = pick(options.Cases, fullfile(root, 'testcases', 'aeb_testcases.csv'));
sequences_file = pick(options.Sequences, fullfile(root, 'testcases', 'aeb_sequences.csv'));
results_dir = pick(options.Results, fullfile(here, 'results'));
if ~isfolder(results_dir)
    mkdir(results_dir);
end

mdl = 'aeb_model';
if ~isfile(fullfile(here, [mdl '.slx']))
    build_model();
end
load_system(fullfile(here, [mdl '.slx']));
cleanup = onCleanup(@() close_system(mdl, 0));

names = {'NO_ACTION', 'BRAKE', 'FAULT'};
rows = {};
coverage = [];

% Stateless decisions: every case is one step of a single simulation.
cases = read_cases(cases_file, false);
if height(cases) > 0
    [raw, ~, cov] = simulate(mdl, cases, ones(height(cases), 1));
    coverage = accumulate(coverage, cov);
    for k = 1:height(cases)
        rows(end + 1, :) = result_row('decision', cases(k, :), 1, 0, names{raw(k) + 1}); %#ok<AGROW>
    end
end

% Timed sequences: one simulation per test case, so the latch starts fresh.
steps = read_cases(sequences_file, true);
ids = unique(steps.TC_ID, 'stable');
for i = 1:numel(ids)
    sequence = steps(steps.TC_ID == ids(i), :);
    [~, action, cov] = simulate(mdl, sequence, sequence.dt_ms);
    coverage = accumulate(coverage, cov);
    for k = 1:height(sequence)
        rows(end + 1, :) = result_row('sequence', sequence(k, :), k, sequence.dt_ms(k), names{action(k) + 1}); %#ok<AGROW>
    end
end

write_results(fullfile(results_dir, 'mil_results.csv'), rows);
failed = sum(strcmp(rows(:, 10), 'FAIL'));
fprintf('MIL: %d samples, %d passed, %d failed\n', size(rows, 1), size(rows, 1) - failed, failed);

write_coverage(fullfile(results_dir, 'coverage_summary.csv'), coverage, mdl);
end

function value = pick(override, default)
if strlength(override) > 0
    value = char(override);
else
    value = default;
end
end

function cases = read_cases(file, is_sequence)
options = detectImportOptions(file, 'Delimiter', ',', 'TextType', 'string');
options = setvartype(options, {'TC_ID', 'REQ_ID', 'expected'}, 'string');
numeric = {'speed_kph', 'obstacle_m', 'sensor_age_ms'};
if is_sequence
    numeric{end + 1} = 'dt_ms';
end
options = setvartype(options, numeric, 'double');
cases = readtable(file, options);
end

function [raw, action, coverage] = simulate(mdl, cases, dt_ms)
count = height(cases);
time = (0:count - 1)';
detected = double(~isnan(cases.obstacle_m));
distance = cases.obstacle_m;
distance(isnan(distance)) = 0;

in = Simulink.SimulationInput(mdl);
in = in.setExternalInput([time, cases.speed_kph, detected, distance, cases.sensor_age_ms, dt_ms]);
in = in.setModelParameter( ...
    'StopTime', num2str(count - 1), ...
    'CovEnable', 'on', ...
    'CovMetricStructuralLevel', 'MCDC', ...
    'CovSaveSingleToWorkspaceVar', 'on', ...
    'CovSaveName', 'covdata', ...
    'CovHtmlReporting', 'off');
out = sim(in);

raw = round(out.yout{1}.Values.Data(:));
action = round(out.yout{2}.Values.Data(:));
coverage = out.covdata;
end

function total = accumulate(total, coverage)
if isempty(total)
    total = coverage;
else
    total = total + coverage;
end
end

function row = result_row(kind, record, step, dt_ms, model_output)
if isnan(record.obstacle_m)
    obstacle = '';
else
    obstacle = sprintf('%g', record.obstacle_m);
end
if model_output == record.expected
    verdict = 'PASS';
else
    verdict = 'FAIL';
end
row = {kind, char(record.TC_ID), step, sprintf('%g', record.speed_kph), obstacle, ...
    record.sensor_age_ms, dt_ms, char(record.expected), model_output, verdict};
end

function write_results(file, rows)
fid = fopen(file, 'w');
closer = onCleanup(@() fclose(fid));
fprintf(fid, 'kind,tc_id,step,speed_kph,obstacle_m,sensor_age_ms,dt_ms,expected,model_output,verdict\n');
for k = 1:size(rows, 1)
    fprintf(fid, '%s,%s,%d,%s,%s,%d,%d,%s,%s,%s\n', rows{k, :});
end
end

function write_coverage(file, coverage, mdl)
fid = fopen(file, 'w');
closer = onCleanup(@() fclose(fid));
fprintf(fid, 'metric,covered,total,percent\n');
metrics = {'decision', @decisioninfo; 'condition', @conditioninfo; 'mcdc', @mcdcinfo};
for k = 1:size(metrics, 1)
    counts = metrics{k, 2}(coverage, mdl);
    if isempty(counts)
        continue
    end
    percent = 100 * counts(1) / counts(2);
    fprintf(fid, '%s,%d,%d,%.1f\n', metrics{k, 1}, counts(1), counts(2), percent);
    fprintf('coverage %-9s %d/%d (%.1f%%)\n', metrics{k, 1}, counts(1), counts(2), percent);
end
end
