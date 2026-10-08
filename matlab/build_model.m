function build_model()
%BUILD_MODEL Create aeb_model.slx from scratch.
%
%   The model has two parts:
%     decide       MATLAB Function block, the stateless decision (REQ-01, 02, 03, 05)
%     fault_latch  Stateflow chart, the fault latch and recovery (REQ-04)
%
%   One simulation step is one sample. dt_ms says how much time that sample
%   stands for, so a timed test sequence is one step per row.
%
%   Actions are numbers on the signal lines: 0 NO_ACTION, 1 BRAKE, 2 FAULT.

here = fileparts(mfilename('fullpath'));
mdl = 'aeb_model';
file = fullfile(here, [mdl '.slx']);

if bdIsLoaded(mdl)
    close_system(mdl, 0);
end
if isfile(file)
    delete(file);
end

new_system(mdl);
set_param(mdl, ...
    'SolverType', 'Fixed-step', ...
    'Solver', 'FixedStepDiscrete', ...
    'FixedStep', '1', ...
    'StopTime', '0', ...
    'SaveOutput', 'on', ...
    'SaveFormat', 'Dataset', ...
    'ReturnWorkspaceOutputs', 'on');

% Inputs
inputs = {'speed_kph', 'obstacle_detected', 'obstacle_m', 'sensor_age_ms', 'dt_ms'};
for k = 1:numel(inputs)
    y = 40 + 60 * (k - 1);
    add_block('simulink/Sources/In1', [mdl '/' inputs{k}], ...
        'Position', [40 y 70 y + 14], ...
        'OutDataTypeStr', 'double', ...
        'SampleTime', '1', ...
        'Interpolate', 'off');
end

% Stateless decision
decide = [mdl '/decide'];
add_block('simulink/User-Defined Functions/MATLAB Function', decide, ...
    'Position', [200 30 380 230]);
config = get_param(decide, 'MATLABFunctionConfiguration');
config.FunctionScript = strjoin({
    'function action = decide(speed_kph, obstacle_detected, obstacle_m, sensor_age_ms)'
    '% Stateless AEB-lite decision. 0 NO_ACTION, 1 BRAKE, 2 FAULT.'
    'SPEED_MIN = 0.0;'
    'SPEED_MAX = 250.0;'
    'BRAKE_SPEED_KPH = 30.0;'
    'DETECT_RANGE_M = 20.0;'
    'SENSOR_TIMEOUT_MS = 200;'
    ''
    'if ~(speed_kph >= SPEED_MIN && speed_kph <= SPEED_MAX)'
    '    action = 2;'
    'elseif sensor_age_ms >= SENSOR_TIMEOUT_MS'
    '    action = 2;'
    'elseif speed_kph >= BRAKE_SPEED_KPH && obstacle_detected ~= 0 && obstacle_m <= DETECT_RANGE_M'
    '    action = 1;'
    'else'
    '    action = 0;'
    'end'
    }, newline);

% Fault latch
latch = [mdl '/fault_latch'];
add_block('sflib/Chart', latch, 'Position', [470 100 650 230]);
chart = find(sfroot, '-isa', 'Stateflow.Chart', 'Path', latch);
chart.ActionLanguage = 'MATLAB';
chart.ExecuteAtInitialization = true;

add_data(chart, 'raw_action', 'Input', '');
add_data(chart, 'dt_ms', 'Input', '');
add_data(chart, 'action', 'Output', '0');
add_data(chart, 'healthy_ms', 'Local', '0');
add_data(chart, 'FAULT', 'Constant', '2');
add_data(chart, 'RECOVERY_MS', 'Constant', '1000');

normal = Stateflow.State(chart);
normal.Name = 'NORMAL';
normal.Position = [300 60 240 70];
normal.LabelString = sprintf('NORMAL\ndu: action = raw_action;');

latched = Stateflow.State(chart);
latched.Name = 'FAULT_LATCHED';
latched.Position = [270 330 300 150];
latched.LabelString = sprintf([ ...
    'FAULT_LATCHED\n' ...
    'du:\n' ...
    'if raw_action == FAULT\n' ...
    '    healthy_ms = 0;\n' ...
    'else\n' ...
    '    healthy_ms = healthy_ms + dt_ms;\n' ...
    'end\n' ...
    'action = FAULT;']);

initial = Stateflow.Transition(chart);
initial.Destination = normal;
initial.DestinationOClock = 0;
initial.SourceEndpoint = [420 20];

% Down the right side into the latch, back up the left side. Labels sit
% outside the states so nothing overlaps.
to_fault = Stateflow.Transition(chart);
to_fault.Source = normal;
to_fault.Destination = latched;
to_fault.SourceOClock = 5;
to_fault.DestinationOClock = 1;
to_fault.LabelString = sprintf('[raw_action == FAULT]\n{healthy_ms = 0; action = FAULT;}');
to_fault.LabelPosition = [560 200 230 34];

recover = Stateflow.Transition(chart);
recover.Source = latched;
recover.Destination = normal;
recover.SourceOClock = 11;
recover.DestinationOClock = 7;
recover.LabelString = sprintf([ ...
    '[raw_action ~= FAULT && healthy_ms + dt_ms >= RECOVERY_MS]\n' ...
    '{healthy_ms = 0; action = raw_action;}']);
recover.LabelPosition = [20 200 280 34];

% Outputs
add_block('simulink/Sinks/Out1', [mdl '/raw_action'], 'Position', [740 60 770 74]);
add_block('simulink/Sinks/Out1', [mdl '/action'], 'Position', [740 160 770 174]);

% Wiring
add_line(mdl, 'speed_kph/1', 'decide/1', 'autorouting', 'on');
add_line(mdl, 'obstacle_detected/1', 'decide/2', 'autorouting', 'on');
add_line(mdl, 'obstacle_m/1', 'decide/3', 'autorouting', 'on');
add_line(mdl, 'sensor_age_ms/1', 'decide/4', 'autorouting', 'on');
add_line(mdl, 'decide/1', 'raw_action/1', 'autorouting', 'on');
add_line(mdl, 'decide/1', 'fault_latch/1', 'autorouting', 'on');
add_line(mdl, 'dt_ms/1', 'fault_latch/2', 'autorouting', 'on');
add_line(mdl, 'fault_latch/1', 'action/1', 'autorouting', 'on');

save_system(mdl, file);
close_system(mdl, 0);
fprintf('saved %s\n', file);
end

function add_data(chart, name, scope, initial_value)
data = Stateflow.Data(chart);
data.Name = name;
data.Scope = scope;
if ~isempty(initial_value)
    data.Props.InitialValue = initial_value;
end
end
