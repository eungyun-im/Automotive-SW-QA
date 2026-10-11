function design_verifier_properties()
%DESIGN_VERIFIER_PROPERTIES Prove the requirements on the model, and catch seeded defects.
%
%   Each requirement is written as a property of the model (an Assertion block
%   that Design Verifier tries to prove for every possible input, not for a
%   list of test cases):
%     REQ-03   a sensor age of 200 ms or more gives FAULT
%     REQ-05   a speed outside 0 to 250 km/h gives FAULT
%     REQ-01   brake conditions give BRAKE (sufficient) and BRAKE only under
%              brake conditions (necessary)
%     REQ-02   speed below 30 km/h with a valid sensor gives NO_ACTION
%     REQ-04   the fault latch never hides a fault of the decision
%     range    the outputs are 0, 1 or 2
%   The properties are checked on the model as it is. Then five defects are
%   written into the decision one at a time (five at a boundary, one in the
%   middle of the input range), and Design Verifier is run again. For every
%   defect the table says which property was falsified, with which input, and
%   whether the designed test cases of testcases/aeb_testcases.csv also fail.
%
%   Writes results/dv_properties.csv and results/dv_defects.csv. Takes about
%   fifteen minutes.

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
results_dir = fullfile(here, 'results');
if ~isfolder(results_dir)
    mkdir(results_dir);
end
tmp = fullfile(tempdir, 'aeb_props');
if isfolder(tmp)
    rmdir(tmp, 's');
end
mkdir(tmp);
old_dir = cd(tmp);
addpath(tmp);
cleanup = onCleanup(@() close_all(old_dir, tmp));

properties = {'REQ-03', 'a sensor age of 200 ms or more gives FAULT'; ...
    'REQ-05', 'a speed outside 0 to 250 km/h gives FAULT'; ...
    'REQ-01', 'brake conditions give BRAKE'; ...
    'REQ-01', 'BRAKE only under brake conditions'; ...
    'REQ-02', 'speed below 30 km/h with a valid sensor gives NO_ACTION'; ...
    'REQ-04', 'the fault latch never hides a fault'; ...
    'range', 'outputs are 0, 1 or 2'};

source = fileread(fullfile(here, 'build_model.m'));
decide_script = extract_decide_script(source);

% 1. The model as it is
build_props_model(fullfile(here, 'aeb_model.slx'), 'aeb_props', decide_script, properties);
[labels, statuses, ~] = prove('aeb_props', tmp);
fid = fopen(fullfile(results_dir, 'dv_properties.csv'), 'w');
fprintf(fid, 'requirement,property,status\n');
for k = 1:size(properties, 1)
    fprintf(fid, '%s,%s,%s\n', properties{k, 1}, properties{k, 2}, statuses{k});
    fprintf('%-7s %-62s %s\n', properties{k, 1}, properties{k, 2}, statuses{k});
end
fclose(fid);

% 2. Seeded defects, one at a time
defects = {
    'D1 sensor timeout: ">=" becomes ">"', 'sensor_age_ms >= SENSOR_TIMEOUT_MS', 'sensor_age_ms > SENSOR_TIMEOUT_MS';
    'D2 detection range: "<=" becomes "<"', 'obstacle_m <= DETECT_RANGE_M', 'obstacle_m < DETECT_RANGE_M';
    'D3 brake speed: ">=" becomes ">"', 'speed_kph >= BRAKE_SPEED_KPH', 'speed_kph > BRAKE_SPEED_KPH';
    'D4 speed limit 250 becomes 255', 'SPEED_MAX = 250.0;', 'SPEED_MAX = 255.0;';
    'D5 brake check before the sensor check', '', '';
    'D6 an obstacle closer than 1 m is ignored', 'obstacle_detected ~= 0 && obstacle_m <= DETECT_RANGE_M', 'obstacle_detected ~= 0 && obstacle_m >= 1 && obstacle_m <= DETECT_RANGE_M'};
cases = readtable(fullfile(root, 'testcases', 'aeb_testcases.csv'), 'Delimiter', ',', 'TextType', 'string');
fid = fopen(fullfile(results_dir, 'dv_defects.csv'), 'w');
fprintf(fid, 'defect,falsified_property,counterexample,designed_tests_fail\n');
for k = 1:size(defects, 1)
    if ~isempty(defects{k, 2})
        script = strrep(decide_script, defects{k, 2}, defects{k, 3});
        assert(~strcmp(script, decide_script), 'Defect %d was not applied', k);
    else
        script = swap_order(decide_script);
    end
    name = sprintf('aeb_props_d%d', k);
    build_props_model(fullfile(here, 'aeb_model.slx'), name, script, properties);
    [labels, statuses, counter] = prove(name, tmp);
    falsified = find(strcmp(statuses, 'Falsified'));
    designed = designed_tests_fail(name, cases);
    if isempty(falsified)
        fprintf(fid, '"%s",none,,%d\n', strrep(defects{k, 1}, '"', ''''), designed);
        fprintf('%-45s no property falsified (designed tests fail: %d)\n', defects{k, 1}, designed);
    else
        for j = falsified(:)'
            fprintf(fid, '"%s","%s %s","%s",%d\n', strrep(defects{k, 1}, '"', ''''), properties{j, 1}, properties{j, 2}, counter{j}, designed);
            fprintf('%-45s falsified: %s %s | %s | designed tests fail: %d\n', defects{k, 1}, properties{j, 1}, properties{j, 2}, counter{j}, designed);
        end
    end
end
fclose(fid);
end

function build_props_model(model_file, name, decide_script, properties)
% A copy of the model with a property block and one Assertion block per property.
copyfile(model_file, fullfile(tempdir, 'aeb_props', [name '.slx']));
load_system(name);
for input = {'speed_kph', 'obstacle_detected', 'obstacle_m', 'sensor_age_ms', 'dt_ms'}
    limits = containers.Map({'speed_kph', 'obstacle_detected', 'obstacle_m', 'sensor_age_ms', 'dt_ms'}, ...
        {[-50 300], [0 1], [0 200], [0 5000], [0 1000]});
    range = limits(input{1});
    set_param([name '/' input{1}], 'OutMin', num2str(range(1)), 'OutMax', num2str(range(2)));
end
config = get_param([name '/decide'], 'MATLABFunctionConfiguration');
config.FunctionScript = decide_script;

block = [name '/props'];
add_block('simulink/User-Defined Functions/MATLAB Function', block, 'Position', [200 300 420 520]);
config = get_param(block, 'MATLABFunctionConfiguration');
config.FunctionScript = strjoin({
    'function [p_req03, p_req05, p_req01_suff, p_req01_nec, p_req02, p_latch, p_range] = props(speed, detected, dist, age, raw, action)'
    'valid = speed >= 0 && speed <= 250;'
    'fresh = age < 200;'
    'near = detected ~= 0 && dist <= 20;'
    'p_req03 = ~(age >= 200) || raw == 2;'
    'p_req05 = valid || raw == 2;'
    'p_req01_suff = ~(valid && fresh && speed >= 30 && near) || raw == 1;'
    'p_req01_nec = ~(raw == 1) || (valid && fresh && speed >= 30 && near);'
    'p_req02 = ~(valid && fresh && speed < 30) || raw == 0;'
    'p_latch = ~(raw == 2) || action == 2;'
    'p_range = (raw == 0 || raw == 1 || raw == 2) && (action == 0 || action == 1 || action == 2);'
    }, newline);
sources = {'speed_kph/1', 'obstacle_detected/1', 'obstacle_m/1', 'sensor_age_ms/1', 'decide/1', 'fault_latch/1'};
for k = 1:numel(sources)
    add_line(name, sources{k}, sprintf('props/%d', k), 'autorouting', 'on');
end
for k = 1:size(properties, 1)
    assertion = sprintf('%s/Assert %d', name, k);
    add_block('simulink/Model Verification/Assertion', assertion, 'Position', [520 300 + 40 * k 560 320 + 40 * k]);
    add_line(name, sprintf('props/%d', k), sprintf('Assert %d/1', k), 'autorouting', 'on');
end
save_system(name);
end

function [labels, statuses, counter] = prove(name, tmp)
% Run property proving and return the status and a counterexample for each Assertion block.
opts = sldvoptions;
opts.Mode = 'PropertyProving';
opts.MaxProcessTime = 300;
opts.SaveHarnessModel = 'off';
opts.SaveReport = 'off';
opts.OutputDir = fullfile(tmp, ['out_' name]);
[status, files] = sldvrun(name, opts, true);
assert(status == 1, 'Design Verifier did not finish for %s (status %d)', name, status);
data = load(files.DataFile).sldvData;
objectives = data.Objectives;
count = numel(objectives);
labels = cell(count, 1);
statuses = cell(count, 1);
counter = repmat({''}, count, 1);
order = zeros(count, 1);
for k = 1:count
    path = data.ModelObjects(objectives(k).modelObjectIdx).slPath;
    token = regexp(path, 'Assert (\d+)', 'tokens', 'once');
    order(k) = str2double(token{1});
    labels{k} = path;
    statuses{k} = objectives(k).status;
    if strcmp(statuses{k}, 'Falsified')
        counter{k} = counterexample_text(data, k);
    end
end
[~, index] = sort(order);
labels = labels(index);
statuses = statuses(index);
counter = counter(index);
end

function text = counterexample_text(data, objective_index)
% The input at the first step of the counterexample that falsifies the objective.
text = 'see the Design Verifier data';
names = {'speed_kph', 'obstacle_detected', 'obstacle_m', 'sensor_age_ms', 'dt_ms'};
for example = reshape(data.CounterExamples, 1, [])
    if any([example.objectives.objectiveIdx] == objective_index)
        parts = cellfun(@(n, v) sprintf('%s=%.6g', n, v(1)), names, example.dataValues(:)', 'UniformOutput', false);
        text = strjoin(parts, ' ');
        return
    end
end
end

function failing = designed_tests_fail(name, cases)
% How many of the designed stateless test cases fail on the model with the defect.
load_system(name);
for block = find_system(name, 'BlockType', 'Assertion')'      % the assertions would stop the run: only the verdicts are wanted
    set_param(block{1}, 'Enabled', 'off');
end
count = height(cases);
detected = double(~isnan(cases.obstacle_m));
distance = cases.obstacle_m;
distance(isnan(distance)) = 0;
matrix = [(0:count - 1)', cases.speed_kph, detected, distance, cases.sensor_age_ms, zeros(count, 1)];
in = Simulink.SimulationInput(name);
in = in.setExternalInput(matrix);
in = in.setModelParameter('StopTime', num2str(count - 1));
out = sim(in);
raw = round(out.yout{1}.Values.Data(:));
names = ["NO_ACTION", "BRAKE", "FAULT"];
failing = sum(names(raw + 1)' ~= string(cases.expected));
end

function script = swap_order(script)
% Check the brake condition before the sensor age.
brake = 'elseif speed_kph >= BRAKE_SPEED_KPH && obstacle_detected ~= 0 && obstacle_m <= DETECT_RANGE_M';
age = 'elseif sensor_age_ms >= SENSOR_TIMEOUT_MS';
assert(contains(script, brake) && contains(script, age));
script = strrep(script, [age newline '    action = 2;' newline brake newline '    action = 1;'], ...
    [brake newline '    action = 1;' newline age newline '    action = 2;']);
end

function script = extract_decide_script(source)
% The text of the MATLAB Function of the decision, as written in build_model.m.
tokens = regexp(source, 'config\.FunctionScript = strjoin\(\{(.*?)\}, newline\);', 'tokens', 'once');
lines = regexp(tokens{1}, '''(.*?)''(?=\s*$)', 'tokens', 'lineanchors');
parts = cellfun(@(c) strrep(c{1}, '''''', ''''), lines, 'UniformOutput', false);
script = strjoin(parts, newline);
end

function close_all(old_dir, tmp)
bdclose all;
cd(old_dir);
rmpath(tmp);
end
