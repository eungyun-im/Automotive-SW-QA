function change_impact()
%CHANGE_IMPACT Which test cases does a requirement change make stale?
%
%   For a few changes of a requirement (a threshold moves), compare two answers:
%     links   the test cases the Requirements Toolbox marks as affected: the
%             links whose destination requirement changed
%     stale   the test cases whose designed expected result is no longer right
%             under the changed requirement, found by recomputing it
%   A test case that is stale but not marked is a miss; a test case that is
%   marked but not stale is review work that was not needed.
%
%   Every scenario runs on a temporary copy, so the committed requirement
%   set and test file stay unchanged. Writes results/change_impact.csv.
%
%   The recomputation is a small independent function of this file
%   (decision_under), not the Simulink model.

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
results_dir = fullfile(here, 'results');
if ~isfolder(results_dir)
    mkdir(results_dir);
end
cases = readtable(fullfile(root, 'testcases', 'aeb_testcases.csv'), ...
    'Delimiter', ',', 'TextType', 'string', 'ReadVariableNames', true);
cases.obstacle_m = double(cases.obstacle_m);

ge = char(8805); le = char(8804);
% name, parameters of the changed behaviour, edits [requirement, pattern, replacement]
scenarios = {
    'S1 brake speed 30 -> 35 (REQ-01 and REQ-02 updated)', struct('brake_speed', 35), {
        'REQ-01', ['(' ge '\s*)30'], '${num}'; 'REQ-02', '(<\s*)30', '${num}'}, 35;
    'S2 brake speed 30 -> 25 (REQ-01 and REQ-02 updated)', struct('brake_speed', 25), {
        'REQ-01', ['(' ge '\s*)30'], '${num}'; 'REQ-02', '(<\s*)30', '${num}'}, 25;
    'S3 detection range 20 -> 15 m (REQ-01)', struct('range', 15), {
        'REQ-01', ['(' le '\s*)20'], '${num}'}, 15;
    'S4 sensor timeout 200 -> 250 ms (REQ-03)', struct('timeout', 250), {
        'REQ-03', ['(' ge '\s*)200'], '${num}'}, 250;
    'S5 valid speed up to 250 -> 120 km/h (REQ-05)', struct('speed_max', 120), {
        'REQ-05', '(\[0,\s*)250', '${num}'}, 120;
    'S6 brake speed 30 -> 25, REQ-02 left unchanged', struct('brake_speed', 25), {
        'REQ-01', ['(' ge '\s*)30'], '${num}'}, 25;
};

fid = fopen(fullfile(results_dir, 'change_impact.csv'), 'w');
fprintf(fid, 'scenario,TC_ID,REQ_ID,marked_by_links,stale\n');
fprintf('%-52s %7s %6s %4s %4s %4s\n', 'scenario', 'marked', 'stale', 'TP', 'FP', 'FN');
for s = 1:size(scenarios, 1)
    [marked, linked_req] = marked_by_links(here, scenarios{s, 3}, scenarios{s, 4});
    stale = stale_tests(cases, scenarios{s, 2});
    names = cellstr(cases.TC_ID);
    is_marked = ismember(names, marked);
    is_stale = ismember(names, stale);
    for k = 1:numel(names)
        fprintf(fid, '"%s",%s,%s,%d,%d\n', scenarios{s, 1}, names{k}, char(cases.REQ_ID(k)), is_marked(k), is_stale(k));
    end
    fprintf('%-52s %7d %6d %4d %4d %4d\n', scenarios{s, 1}, sum(is_marked), sum(is_stale), ...
        sum(is_marked & is_stale), sum(is_marked & ~is_stale), sum(~is_marked & is_stale));
end
fclose(fid);
end

function [marked, linked_req] = marked_by_links(here, edits, new_value)
% Apply the requirement edits to a temporary copy and read which test case links the toolbox flags.
tmp = fullfile(tempdir, 'aeb_change_impact');
if isfolder(tmp)
    slreq.clear;
    rmdir(tmp, 's');
end
mkdir(tmp);
for file = {'aeb_model.slx', 'aeb_requirements.slreqx', 'aeb_tests.mldatx'}
    copyfile(fullfile(here, file{1}), tmp);
end
for f = dir(fullfile(here, '*.slmx'))'
    copyfile(fullfile(f.folder, f.name), tmp);
end
copyfile(fullfile(here, 'test_data'), fullfile(tmp, 'test_data'));

old_dir = cd(tmp);
addpath(tmp);
cleanup = onCleanup(@() close_all(tmp, old_dir));
slreq.clear;
sltest.testmanager.clear;
load_system(fullfile(tmp, 'aeb_model.slx'));
req_set = slreq.load(fullfile(tmp, 'aeb_requirements.slreqx'));
sltest.testmanager.load(fullfile(tmp, 'aeb_tests.mldatx'));
for k = 1:size(edits, 1)
    req = req_set.find('Type', 'Requirement', 'Id', edits{k, 1});
    req.Summary = regexprep(req.Summary, edits{k, 2}, ['$1' num2str(new_value)]);
end
req_set.save();

marked = {};
linked_req = {};
for link_set = reshape(slreq.find('Type', 'LinkSet'), 1, [])
    if contains(link_set.Filename, 'mldatx')
        for link = reshape(link_set.getLinksWithChangedDestination, 1, [])
            marked{end + 1} = link.getSourceLabel; %#ok<AGROW>
        end
    end
end
end

function close_all(tmp, old_dir)
slreq.clear;
sltest.testmanager.clear;
sltest.testmanager.close;
bdclose all;
cd(old_dir);
rmpath(tmp);
end

function stale = stale_tests(cases, change)
% Test cases whose designed expected result differs from the recomputed one under the changed parameters.
params = struct('brake_speed', 30, 'range', 20, 'timeout', 200, 'speed_max', 250);
for field = fieldnames(change)'
    params.(field{1}) = change.(field{1});
end
stale = {};
for k = 1:height(cases)
    now = decision_under(cases.speed_kph(k), cases.obstacle_m(k), cases.sensor_age_ms(k), params);
    if now ~= string(cases.expected(k))
        stale{end + 1} = char(cases.TC_ID(k)); %#ok<AGROW>
    end
end
end

function action = decision_under(speed, obstacle, age, p)
% The stateless decision of REQ-01, 02, 03 and 05 with parameters, written for this comparison.
if ~(speed >= 0 && speed <= p.speed_max)
    action = "FAULT";
elseif age >= p.timeout
    action = "FAULT";
elseif speed >= p.brake_speed && ~isnan(obstacle) && obstacle <= p.range
    action = "BRAKE";
else
    action = "NO_ACTION";
end
end
