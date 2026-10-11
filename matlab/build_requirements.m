function build_requirements()
%BUILD_REQUIREMENTS Create the requirement set and link it to the model.
%
%   Reads the requirement table of requirements/aeb_requirements.md and
%   creates matlab/aeb_requirements.slreqx with one requirement per row
%   (Requirements Toolbox). Each requirement gets an "Implement" link to the
%   model element that realises it:
%     REQ-01, 02, 03, 05   aeb_model/decide        (the stateless decision)
%     REQ-04               aeb_model/fault_latch   (the fault latch chart)
%
%   The links to the test cases are added by build_tests.m, which creates the
%   test file from the CSV files. Run this first.
%
%   Files written next to the model: aeb_requirements.slreqx and the link set
%   of the model (*.slmx). Commit them.

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
mdl = 'aeb_model';

model_file = fullfile(here, [mdl '.slx']);
if ~isfile(model_file)
    build_model();
end
slreq.clear;
if bdIsLoaded(mdl)
    close_system(mdl, 0);
end

% Start clean: remove the files of an earlier run before the model is loaded,
% because loading the model would load its old link set and requirement set.
for pattern = {'*.slreqx', '*.slmx'}
    for f = dir(fullfile(here, pattern{1}))'
        delete(fullfile(f.folder, f.name));
    end
end
load_system(model_file);
slreq.clear;

text = fileread(fullfile(root, 'requirements', 'aeb_requirements.md'), 'Encoding', 'UTF-8');
rows = regexp(text, '^\|\s*(REQ-\d+)\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|\s*$', 'tokens', 'lineanchors');
assert(~isempty(rows), 'No requirement rows found in aeb_requirements.md');

implemented_by = containers.Map( ...
    {'REQ-01', 'REQ-02', 'REQ-03', 'REQ-04', 'REQ-05'}, ...
    {'decide', 'decide', 'decide', 'fault_latch', 'decide'});

req_set = slreq.new(fullfile(here, 'aeb_requirements'));
for k = 1:numel(rows)
    id = rows{k}{1};
    summary = rows{k}{2};
    expected = rows{k}{3};
    req = req_set.add('Id', id, 'Summary', summary, ...
        'Description', sprintf('%s\nExpected output: %s', summary, expected));
    if isKey(implemented_by, id)
        link = slreq.createLink([mdl '/' implemented_by(id)], req);
        link.Type = 'Implement';
    else
        warning('build_requirements:noImplementation', '%s has no implementing model element.', id);
    end
end
req_set.save();
for link_set = reshape(slreq.find('Type', 'LinkSet'), 1, [])
    link_set.save();
end
fprintf('Requirement set with %d requirements written to matlab/aeb_requirements.slreqx\n', numel(rows));

slreq.clear;
close_system(mdl, 0);
end
