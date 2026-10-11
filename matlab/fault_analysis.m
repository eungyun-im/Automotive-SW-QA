function fault_analysis()
%FAULT_ANALYSIS Inject sensor faults into the model and classify their effect.
%
%   Simulink Fault Analyzer: ten faults on the input signals (a signal stuck
%   at a value, or scaled), each injected alone. The model is run with every
%   fault on two sets of stimuli:
%     the 12 designed test cases of testcases/aeb_testcases.csv (single samples,
%       the decision output is compared), and
%     the test cases that Design Verifier generated (timed sequences, the
%       output of the fault latch is compared; run design_verifier_tests.m first).
%   The effect of a fault on a stimulus is the difference between the run with
%   the fault and the run without it:
%     no effect        same output
%     safe deviation   the output is FAULT where the nominal output is not (the
%                      system goes to its safe state; the function is lost)
%     missed brake     nominal BRAKE, faulted output is not BRAKE
%     spurious brake   nominal is not BRAKE, faulted output is BRAKE
%   A fault with a missed or spurious brake and no FAULT on the same stimulus
%   is undetected by the model. This classification is the engineer's reading
%   of the outputs; the rating of severity, exposure and controllability is
%   the hazard analysis (docs/hara.md) and is not done here.
%
%   Writes results/fault_list.csv, results/fault_effects.csv and
%   results/fault_summary.csv.

here = fileparts(mfilename('fullpath'));
root = fileparts(here);
results_dir = fullfile(here, 'results');
if ~isfolder(results_dir)
    mkdir(results_dir);
end
tmp = fullfile(tempdir, 'aeb_fa');
if isfolder(tmp)
    rmdir(tmp, 's');
end
mkdir(tmp);
copyfile(fullfile(here, 'aeb_model.slx'), fullfile(tmp, 'aeb_fa.slx'));
old_dir = cd(tmp);
addpath(tmp);
cleanup = onCleanup(@() close_all(old_dir, tmp));
load_system('aeb_fa');

% name, input signal, behaviour, value of the behaviour, what it models
defs = {
    'speed_stuck_0',      'speed_kph',         'Stuck-at-Constant', 0,   'speed signal stuck at 0';
    'speed_gain_half',     'speed_kph',         'Gain',              0.5, 'speed reads half of the true value';
    'speed_gain_1p5',     'speed_kph',         'Gain',              1.5, 'speed reads 1.5 times the true value';
    'detected_stuck_0',   'obstacle_detected', 'Stuck-at-Constant', 0,   'obstacle flag stuck at "nothing detected"';
    'detected_stuck_1',   'obstacle_detected', 'Stuck-at-Constant', 1,   'obstacle flag stuck at "obstacle detected"';
    'distance_gain_2',    'obstacle_m',        'Gain',              2,   'distance reads twice the true value';
    'distance_stuck_0',   'obstacle_m',        'Stuck-at-Constant', 0,   'distance stuck at 0 m';
    'age_stuck_0',        'sensor_age_ms',     'Stuck-at-Constant', 0,   'sensor age stuck at 0 (stale data looks fresh)';
    'age_gain_10',        'sensor_age_ms',     'Gain',              10,  'sensor age reads ten times the true value';
    'dt_stuck_0',         'dt_ms',             'Stuck-at-Constant', 0,   'time step stuck at 0 (recovery timer does not run)'};
faults = [];
ports = {};
for k = 1:size(defs, 1)
    port = get_param(['aeb_fa/' defs{k, 2}], 'PortHandles');
    fault = Simulink.fault.addFault(port.Outport(1), 'Name', defs{k, 1}, 'Description', defs{k, 5});
    fault.addBehavior('aeb_fa_faults', 'FaultBehavior', ['mwfaultlib/' defs{k, 3}]);
    inner = [fault.getBehavior '/' ternary(strcmp(defs{k, 3}, 'Gain'), 'Gain', 'Constant')];
    if strcmp(defs{k, 3}, 'Gain')
        set_param(inner, 'Gain', num2str(defs{k, 4}));
    else
        set_param(inner, 'Value', num2str(defs{k, 4}));
    end
    faults = [faults, fault]; %#ok<AGROW>
    ports{end + 1} = fault.ModelElement; %#ok<AGROW>
end
fid = fopen(fullfile(results_dir, 'fault_list.csv'), 'w');
fprintf(fid, 'fault,signal,behaviour,value,description\n');
for k = 1:size(defs, 1)
    fprintf(fid, '%s,%s,%s,%g,"%s"\n', defs{k, 1}, defs{k, 2}, defs{k, 3}, defs{k, 4}, defs{k, 5});
end
fclose(fid);

% Stimuli
cases = readtable(fullfile(root, 'testcases', 'aeb_testcases.csv'), 'Delimiter', ',', 'TextType', 'string');
count = height(cases);
detected = double(~isnan(cases.obstacle_m));
distance = cases.obstacle_m;
distance(isnan(distance)) = 0;
designed = struct('name', 'designed', 'matrix', [(0:count - 1)', cases.speed_kph, detected, distance, cases.sensor_age_ms, zeros(count, 1)], ...
    'ids', {cellstr(cases.TC_ID)}, 'output', 1);
stimuli = designed;
generated_file = fullfile(results_dir, 'dv_generated_tests.csv');
if isfile(generated_file)
    generated = readtable(generated_file);
    for k = reshape(unique(generated.test_case), 1, [])
        rows = generated(generated.test_case == k, :);
        matrix = [rows.time, rows.speed_kph, rows.obstacle_detected, rows.obstacle_m, rows.sensor_age_ms, rows.dt_ms];
        stimuli(end + 1) = struct('name', sprintf('dv-%d', k), 'matrix', matrix, 'ids', {{sprintf('DV-%d', k)}}, 'output', 2); %#ok<AGROW>
    end
else
    warning('fault_analysis:noGenerated', 'No results/dv_generated_tests.csv: only the designed test cases are used.');
end

names = ["NO_ACTION", "BRAKE", "FAULT"];
effects = {};
for s = 1:numel(stimuli)
    nominal = simulate(stimuli(s), false, faults(1), ports);
    for k = 1:numel(faults)
        faulted = simulate(stimuli(s), true, faults(k), ports);
        n = numel(nominal);
        for i = 1:n
            label = stimuli(s).ids{min(i, numel(stimuli(s).ids))};
            if stimuli(s).output == 2
                label = sprintf('%s step %d', stimuli(s).ids{1}, i);
            end
            effects(end + 1, :) = {defs{k, 1}, label, char(names(nominal(i) + 1)), char(names(faulted(i) + 1)), ...
                classify(nominal(i), faulted(i))}; %#ok<AGROW>
        end
    end
end

fid = fopen(fullfile(results_dir, 'fault_effects.csv'), 'w');
fprintf(fid, 'fault,stimulus,nominal,faulted,effect\n');
for k = 1:size(effects, 1)
    fprintf(fid, '%s,%s,%s,%s,%s\n', effects{k, :});
end
fclose(fid);

classes = {'no effect', 'safe deviation', 'missed brake', 'spurious brake'};
fid = fopen(fullfile(results_dir, 'fault_summary.csv'), 'w');
fprintf(fid, 'fault,stimuli,no_effect,safe_deviation,missed_brake,spurious_brake\n');
fprintf('%-18s %7s %9s %14s %12s %14s\n', 'fault', 'stimuli', 'no effect', 'safe deviation', 'missed brake', 'spurious brake');
for k = 1:size(defs, 1)
    mine = strcmp(effects(:, 1), defs{k, 1});
    counts = cellfun(@(c) sum(mine & strcmp(effects(:, 5), c)), classes);
    fprintf(fid, '%s,%d,%d,%d,%d,%d\n', defs{k, 1}, sum(mine), counts);
    fprintf('%-18s %7d %9d %14d %12d %14d\n', defs{k, 1}, sum(mine), counts);
end
fclose(fid);
end

function out = simulate(stimulus, with_fault, fault, ports)
% Output of one stimulus: the decision (output 1) or the latched action (output 2).
Simulink.fault.injection('aeb_fa', with_fault);
if with_fault
    Simulink.fault.enable(ports, false);       % one fault at a time
    fault.activate;
end
in = Simulink.SimulationInput('aeb_fa');
in = in.setExternalInput(stimulus.matrix);
in = in.setModelParameter('StopTime', num2str(stimulus.matrix(end, 1)));
result = sim(in);
out = round(result.yout{stimulus.output}.Values.Data(:));
if stimulus.output == 2
    out = out(ismember(result.yout{2}.Values.Time, 0:stimulus.matrix(end, 1)));
end
end

function text = classify(nominal, faulted)
if nominal == faulted
    text = 'no effect';
elseif faulted == 2
    text = 'safe deviation';
elseif nominal == 1
    text = 'missed brake';
elseif faulted == 1
    text = 'spurious brake';
else
    text = 'other';
end
end

function value = ternary(condition, a, b)
if condition
    value = a;
else
    value = b;
end
end

function close_all(old_dir, tmp)
Simulink.fault.injection('aeb_fa', false);
bdclose all;
cd(old_dir);
rmpath(tmp);
end
