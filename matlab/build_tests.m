function build_tests(options)
%BUILD_TESTS Create the Simulink Test file from the designed test cases.
%
%   One test case per row of testcases/aeb_testcases.csv (a single sample)
%   and one per TC_ID of testcases/aeb_sequences.csv (a timed sequence, one
%   sample per row). The inputs come from the CSV. The expected result is a
%   baseline criterion made from the CSV column "expected", not from the model:
%   the baseline file is first captured from the model so that it has the
%   right signal path, and then every value is replaced by the designed one.
%
%   Each test case is linked to its requirement (REQ_ID) with a "Verify"
%   link. Run build_requirements.m first. Writes matlab/aeb_tests.mldatx and
%   the data files in matlab/test_data/.
%
%   build_tests(Cases=file, Sequences=file, Output=folder) overrides the
%   inputs and the output folder (the folder keeps the file name).

arguments
    options.Cases (1, 1) string = ""
    options.Sequences (1, 1) string = ""
    options.Output (1, 1) string = ""
end

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
out_dir = pick(options.Output, here);
cases_file = pick(options.Cases, fullfile(root, 'testcases', 'aeb_testcases.csv'));
sequences_file = pick(options.Sequences, fullfile(root, 'testcases', 'aeb_sequences.csv'));
data_dir = fullfile(out_dir, 'test_data');
tests_file = fullfile(out_dir, 'aeb_tests.mldatx');
req_file = fullfile(out_dir, 'aeb_requirements.slreqx');
mdl = 'aeb_model';

if ~isfolder(data_dir)
    mkdir(data_dir);
end
sltest.testmanager.clear;
slreq.clear;
if bdIsLoaded(mdl)
    close_system(mdl, 0);
end
load_system(fullfile(out_dir, [mdl '.slx']));
addpath(out_dir);
cleanup = onCleanup(@() cleanup_all(mdl, out_dir));

if isfile(tests_file)
    delete(tests_file);
end
test_file = sltest.testmanager.TestFile(tests_file);
suite = test_file.getTestSuites;
suite.Name = 'AEB-lite requirement tests';
placeholder = suite.getTestCases;

cases = read_cases(cases_file, false);
steps = read_cases(sequences_file, true);
made = {};     % TC_ID, REQ_ID

for k = 1:height(cases)
    id = char(cases.TC_ID(k));
    inputs = [0, cases.speed_kph(k), ~isnan(cases.obstacle_m(k)), nan_to_zero(cases.obstacle_m(k)), cases.sensor_age_ms(k), 0];
    add_case(suite, id, char(cases.REQ_ID(k)), inputs, action_code(cases.expected(k)), data_dir, mdl);
    made(end + 1, :) = {id, char(cases.REQ_ID(k))}; %#ok<AGROW>
end
ids = unique(steps.TC_ID, 'stable');
for k = 1:numel(ids)
    s = steps(steps.TC_ID == ids(k), :);
    n = height(s);
    inputs = [(0:n - 1)', s.speed_kph, ~isnan(s.obstacle_m), nan_to_zero(s.obstacle_m), s.sensor_age_ms, s.dt_ms];
    add_case(suite, char(ids(k)), char(s.REQ_ID(1)), inputs, action_code(s.expected), data_dir, mdl);
    made(end + 1, :) = {char(ids(k)), char(s.REQ_ID(1))}; %#ok<AGROW>
end
if ~isempty(placeholder)
    remove(placeholder(1));          % the empty case every new test file starts with
end
test_file.saveToFile;

% Verify links: test case -> requirement
if isfile(req_file)
    req_set = slreq.load(req_file);
    test_cases = suite.getTestCases;
    for k = 1:numel(test_cases)
        row = find(strcmp(made(:, 1), test_cases(k).Name), 1);
        req = req_set.find('Type', 'Requirement', 'Id', made{row, 2});
        link = slreq.createLink(test_cases(k), req);
        link.Type = 'Verify';
    end
    req_set.save();
    for link_set = reshape(slreq.find('Type', 'LinkSet'), 1, [])
        link_set.save();
    end
else
    warning('build_tests:noRequirements', 'No requirement set found: run build_requirements.m first. The test cases are not linked.');
end
fprintf('Test file with %d test cases written to %s\n', size(made, 1), tests_file);
end

function add_case(suite, id, req_id, inputs, expected, data_dir, mdl)
% inputs: one row per sample [time, speed_kph, obstacle_detected, obstacle_m, sensor_age_ms, dt_ms]
names = {'speed_kph', 'obstacle_detected', 'obstacle_m', 'sensor_age_ms', 'dt_ms'};
time = inputs(:, 1);
data = Simulink.SimulationData.Dataset;
for j = 1:numel(names)
    data = data.addElement(timeseries(inputs(:, j + 1), time), names{j});
end
input_file = fullfile(data_dir, [id '_input.mat']);
save_variable(input_file, 'inputs', data);

tc = suite.createTestCase('baseline', id);
tc.setProperty('Model', mdl);
tc.setProperty('OverrideStopTime', true);
tc.setProperty('StopTime', time(end));
tc.Description = sprintf('%s: designed test case, requirement %s', id, req_id);
tc.Tags = {req_id};
in = tc.addInput(input_file, 'CreateIterations', false);
in.map('Mode', 0);                  % by port order

% Baseline: structure from a captured run, values from the test design.
baseline_file = fullfile(data_dir, [id '_expected.mat']);
tc.captureBaselineCriteria(baseline_file, true);
captured = load(baseline_file);
signal = captured.data{2};          % the output 'action' (port 2 of the model outputs)
signal.Values = timeseries(expected, time);
designed = Simulink.SimulationData.Dataset;
designed = designed.addElement(signal);
save_variable(baseline_file, 'data', designed);
tc.addBaselineCriteria(baseline_file, 'RefreshIfExists', true);
end

function save_variable(file, name, value)
s.(name) = value;
save(file, '-struct', 's');
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

function code = action_code(expected)
names = ["NO_ACTION", "BRAKE", "FAULT"];
code = zeros(numel(expected), 1);
for k = 1:numel(expected)
    index = find(names == string(expected(k)));
    assert(~isempty(index), 'Unknown expected result "%s"', expected(k));
    code(k) = index - 1;
end
end

function value = nan_to_zero(value)
value(isnan(value)) = 0;
end

function value = pick(override, default)
if strlength(override) > 0
    value = char(override);
else
    value = default;
end
end

function cleanup_all(mdl, out_dir)
slreq.clear;
sltest.testmanager.clear;
sltest.testmanager.close;
if bdIsLoaded(mdl)
    close_system(mdl, 0);
end
rmpath(out_dir);
end
