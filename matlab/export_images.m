function export_images()
%EXPORT_IMAGES Save pictures of the model and of the Stateflow chart for the README.
%
%   Writes ../docs/img/simulink-model.png and ../docs/img/stateflow-fault-latch.png.

here = fileparts(mfilename('fullpath'));
out = fullfile(fileparts(here), 'docs', 'img');
if ~isfolder(out)
    mkdir(out);
end

mdl = 'aeb_model';
load_system(fullfile(here, [mdl '.slx']));
cleanup = onCleanup(@() close_system(mdl, 0));

print(['-s' mdl], '-dpng', '-r150', fullfile(out, 'simulink-model.png'));

chart = find(sfroot, '-isa', 'Stateflow.Chart', 'Path', [mdl '/fault_latch']);
sfprint(chart, 'png', fullfile(out, 'stateflow-fault-latch.png'));

fprintf('images written to %s\n', out);
end
