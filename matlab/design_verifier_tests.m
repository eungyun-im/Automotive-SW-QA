function design_verifier_tests()
%DESIGN_VERIFIER_TESTS Generate test cases from the model with Simulink Design Verifier.
%
%   Asks Design Verifier for test cases that reach every decision, condition
%   and MC/DC objective of aeb_model, then replays them on the model and
%   measures the coverage with Simulink Coverage, so the number does not rest
%   on the generator's own report. Compare with the designed test cases of
%   testcases/*.csv (matlab/results/coverage_summary.csv).
%
%   The inputs are constrained to physical ranges (a copy of the model with
%   minimum and maximum on the inports), otherwise the generator is free to
%   use negative time steps. Writes
%     results/dv_generated_tests.csv   the generated test vectors
%     results/dv_coverage_summary.csv  coverage of the generated tests
%     results/dv_objectives.csv        objectives by status
%   Takes a few minutes.

here = fileparts(mfilename('fullpath'));
results_dir = fullfile(here, 'results');
if ~isfolder(results_dir)
    mkdir(results_dir);
end

tmp = fullfile(tempdir, 'aeb_dv');
if isfolder(tmp)
    rmdir(tmp, 's');
end
mkdir(tmp);
copyfile(fullfile(here, 'aeb_model.slx'), fullfile(tmp, 'aeb_dv.slx'));
copyfile(fullfile(here, 'aeb_model.slx'), fullfile(tmp, 'aeb_model.slx'));
old_dir = cd(tmp);
addpath(tmp);
cleanup = onCleanup(@() close_all(old_dir, tmp));

% Physical ranges of the inputs, as constraints for the generator.
load_system('aeb_dv');
ranges = {'speed_kph', -50, 300; 'obstacle_detected', 0, 1; 'obstacle_m', 0, 200; ...
    'sensor_age_ms', 0, 5000; 'dt_ms', 0, 1000};
for k = 1:size(ranges, 1)
    set_param(['aeb_dv/' ranges{k, 1}], 'OutMin', num2str(ranges{k, 2}), 'OutMax', num2str(ranges{k, 3}));
end

opts = sldvoptions;
opts.Mode = 'TestGeneration';
opts.ModelCoverageObjectives = 'MCDC';
opts.MaxProcessTime = 600;
opts.SaveHarnessModel = 'off';
opts.SaveReport = 'off';
opts.OutputDir = fullfile(tmp, 'sldv_out');
tic;
[status, files] = sldvrun('aeb_dv', opts, true);
seconds = toc;
assert(status == 1, 'Design Verifier did not finish (status %d)', status);
data = load(files.DataFile).sldvData;
fprintf('Design Verifier: %d test cases, %d objectives, %.0f s\n', numel(data.TestCases), numel(data.Objectives), seconds);

% Objectives by status
statuses = string({data.Objectives.status});
fid = fopen(fullfile(results_dir, 'dv_objectives.csv'), 'w');
fprintf(fid, 'status,objectives\n');
for s = unique(statuses)
    fprintf(fid, '%s,%d\n', s, sum(statuses == s));
end
fclose(fid);

% Test vectors
names = {'speed_kph', 'obstacle_detected', 'obstacle_m', 'sensor_age_ms', 'dt_ms'};
fid = fopen(fullfile(results_dir, 'dv_generated_tests.csv'), 'w');
fprintf(fid, 'test_case,time,%s\n', strjoin(names, ','));
for k = 1:numel(data.TestCases)
    tc = data.TestCases(k);
    for i = 1:numel(tc.timeValues)
        values = cellfun(@(v) v(i), tc.dataValues);
        fprintf(fid, '%d,%g,%s\n', k, tc.timeValues(i), strjoin(arrayfun(@(v) sprintf('%.6g', v), values, 'UniformOutput', false), ','));
    end
end
fclose(fid);

% Replay on the original model and measure the coverage there.
close_system('aeb_dv', 0);
load_system('aeb_model');
total = [];
for k = 1:numel(data.TestCases)
    tc = data.TestCases(k);
    matrix = [tc.timeValues(:), cell2mat(cellfun(@(v) v(:), tc.dataValues(:)', 'UniformOutput', false))];
    in = Simulink.SimulationInput('aeb_model');
    in = in.setExternalInput(matrix);
    in = in.setModelParameter('StopTime', num2str(tc.timeValues(end)), 'CovEnable', 'on', ...
        'CovMetricStructuralLevel', 'MCDC', 'CovSaveSingleToWorkspaceVar', 'on', ...
        'CovSaveName', 'covdata', 'CovHtmlReporting', 'off');
    out = sim(in);
    if isempty(total)
        total = out.covdata;
    else
        total = total + out.covdata;
    end
end
fid = fopen(fullfile(results_dir, 'dv_coverage_summary.csv'), 'w');
fprintf(fid, 'metric,covered,total,percent\n');
metrics = {'decision', @decisioninfo; 'condition', @conditioninfo; 'mcdc', @mcdcinfo};
for k = 1:size(metrics, 1)
    counts = metrics{k, 2}(total, 'aeb_model');
    fprintf(fid, '%s,%d,%d,%.1f\n', metrics{k, 1}, counts(1), counts(2), 100 * counts(1) / counts(2));
    fprintf('generated tests, %-9s %d/%d (%.1f%%)\n', metrics{k, 1}, counts(1), counts(2), 100 * counts(1) / counts(2));
end
fclose(fid);
end

function close_all(old_dir, tmp)
bdclose all;
cd(old_dir);
rmpath(tmp);
end
