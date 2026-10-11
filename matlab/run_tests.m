function run_tests()
%RUN_TESTS Run the Simulink Test file and write the traceability results.
%
%   Runs matlab/aeb_tests.mldatx (made by build_tests.m) and writes
%     results/simulink_test_results.csv   one row per test case: verdict
%     results/traceability.csv            one row per requirement: implementing
%                                         model element, verifying test cases,
%                                         verdicts and the status that the
%                                         Requirements Toolbox derives from them
%
%   A requirement without a verifying test case is reported as such. REQ-04
%   (fault recovery) has none until testcases/aeb_sequences.csv is filled in.

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
results_dir = fullfile(here, 'results');
if ~isfolder(results_dir)
    mkdir(results_dir);
end
mdl = 'aeb_model';
slreq.clear;
sltest.testmanager.clear;
sltest.testmanager.clearResults;
if bdIsLoaded(mdl)
    close_system(mdl, 0);
end
load_system(fullfile(here, [mdl '.slx']));
addpath(here);
cleanup = onCleanup(@() cleanup_all(mdl, here));

req_set = slreq.load(fullfile(here, 'aeb_requirements.slreqx'));
test_file = sltest.testmanager.load(fullfile(here, 'aeb_tests.mldatx'));
result = sltest.testmanager.run;

% The Requirements Toolbox derives the status of a requirement from its links
% and from the latest results of the linked test cases.
req_set.updateImplementationStatus;
req_set.updateVerificationStatus;

% One row per test case
rows = {};
for file_result = reshape(result.getTestFileResults, 1, [])
    for suite_result = reshape(file_result.getTestSuiteResults, 1, [])
        for case_result = reshape(suite_result.getTestCaseResults, 1, [])
            tags = '';
            rows(end + 1, :) = {case_result.Name, tags, char(string(case_result.Outcome))}; %#ok<AGROW>
        end
    end
end
verdict = containers.Map(rows(:, 1), rows(:, 3));

% Requirement of each test case: the requirements linked to the test case
tests_by_requirement = containers.Map();
for suite = reshape(test_file.getTestSuites, 1, [])
    for tc = reshape(suite.getTestCases, 1, [])
        for linked = reshape(tc.Requirements, 1, [])
            id = regexp(linked.description, '^REQ-\d+', 'match', 'once');
            if isKey(tests_by_requirement, id)
                tests_by_requirement(id) = [tests_by_requirement(id), {tc.Name}];
            else
                tests_by_requirement(id) = {tc.Name};
            end
        end
    end
end

fid = fopen(fullfile(results_dir, 'simulink_test_results.csv'), 'w');
fprintf(fid, 'TC_ID,REQ_ID,verdict\n');
trace_rows = {};
for req = reshape(req_set.find('Type', 'Requirement'), 1, [])
    names = {};
    if isKey(tests_by_requirement, req.Id)
        names = sort(tests_by_requirement(req.Id));
    end
    for k = 1:numel(names)
        v = '';
        if isKey(verdict, names{k})
            v = verdict(names{k});
        end
        fprintf(fid, '%s,%s,%s\n', names{k}, req.Id, v);
    end
    implementers = {};
    for link = reshape(req.inLinks, 1, [])
        if strcmp(link.Type, 'Implement')
            implementers{end + 1} = link.source.id; %#ok<AGROW>
        end
    end
    passed = sum(cellfun(@(n) isKey(verdict, n) && strcmp(verdict(n), 'Passed'), names));
    trace_rows(end + 1, :) = {req.Id, numel(implementers), numel(names), passed, ...
        implementation_text(req.getImplementationStatus), verification_text(req.getVerificationStatus)}; %#ok<AGROW>
end
fclose(fid);

fid = fopen(fullfile(results_dir, 'traceability.csv'), 'w');
fprintf(fid, 'REQ_ID,implementing_elements,verifying_tests,passed,implementation_status,verification_status\n');
for k = 1:size(trace_rows, 1)
    fprintf(fid, '%s,%d,%d,%d,%s,%s\n', trace_rows{k, :});
end
fclose(fid);

passed = sum(strcmp(rows(:, 3), 'Passed'));
fprintf('Simulink Test: %d test cases, %d passed, %d not passed\n', size(rows, 1), passed, size(rows, 1) - passed);
for k = 1:size(trace_rows, 1)
    fprintf('  %s: %d implementing, %d verifying tests (%d passed), verification %s\n', ...
        trace_rows{k, 1}, trace_rows{k, 2}, trace_rows{k, 3}, trace_rows{k, 4}, trace_rows{k, 6});
end
end

function cleanup_all(mdl, folder)
Simulink.sdi.clear;
slreq.clear;
sltest.testmanager.clearResults;
sltest.testmanager.clear;
sltest.testmanager.close;
if bdIsLoaded(mdl)
    close_system(mdl, 0);
end
rmpath(folder);
end

function text = implementation_text(status)
if status.implemented > 0
    text = 'Implemented';
elseif status.justified > 0
    text = 'Justified';
else
    text = 'Missing';
end
end

function text = verification_text(status)
if status.failed > 0
    text = 'Failed';
elseif status.unexecuted > 0
    text = 'Unexecuted';
elseif status.passed > 0
    text = 'Passed';
elseif status.justified > 0
    text = 'Justified';
else
    text = 'Missing';
end
end
