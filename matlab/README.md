# Simulink model (model in the loop)

`aeb_model.slx` is the AEB-lite logic as a model:

- **decide**: a MATLAB Function block with the stateless decision (REQ-01, 02, 03, 05).
- **fault_latch**: a Stateflow chart with two states, `NORMAL` and `FAULT_LATCHED`, for the fault latch and recovery (REQ-04).

One simulation step is one sample. The `dt_ms` input says how much time the sample stands for, so a timed test sequence is one step per row. Actions travel as numbers: 0 `NO_ACTION`, 1 `BRAKE`, 2 `FAULT`.

Requires MATLAB with Simulink, Stateflow and Simulink Coverage. Built and run with R2025b.

## Files

| File | Purpose |
|---|---|
| `build_model.m` | Creates `aeb_model.slx` from scratch, so the model is reviewable as text |
| `run_mil.m` | Simulates the model with the designed test cases and writes the results |
| `aeb_model.slx` | The generated model |
| `export_images.m` | Saves pictures of the model and the chart to `docs/img/` for the README |
| `results/mil_results.csv` | One row per simulated sample: inputs, expected result, model output, verdict |
| `results/coverage_summary.csv` | Decision, condition and MC/DC coverage of the model from those test cases |

## Running

In MATLAB, from this folder:

```matlab
build_model   % only needed after changing build_model.m
run_mil
```

Commit the updated `results/` files. `tests/test_back_to_back.py` replays every stored input through the Python reference in CI, so a model that disagrees with the code fails the build even though CI has no MATLAB.

## Checking the model itself

The designed test cases check the requirements. To check that the model implements the same behavior as the reference code, generate inputs from the reference and run them through the model:

```bash
python -m tools.model_check build/model_check
```

```matlab
d = fullfile("..", "build", "model_check");
run_mil(Cases=fullfile(d, "aeb_testcases.csv"), Sequences=fullfile(d, "aeb_sequences.csv"), Results=fullfile(d, "results"))
```

Last run: 504 decision cases and 1500 sequence samples, all matching, with 100 % decision, condition and MC/DC coverage of the model.
