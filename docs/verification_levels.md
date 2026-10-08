# Verification levels

Where this project sits among the usual levels of automotive software verification.

| Level | What runs | What it catches | In this project |
|---|---|---|---|
| MIL (model in the loop) | The control model against test inputs | Errors in the control concept | `matlab/aeb_model.slx`, simulated with the designed test cases |
| SIL (software in the loop) | The production code on a PC | Logic errors, boundary errors, interface errors | `src/c/aeb.c` and `src/aeb.py`, executed by pytest |
| PIL (processor in the loop) | The code compiled for the target processor | Compiler, data type and timing differences | Out of scope |
| HIL (hardware in the loop) | The real ECU against a simulated vehicle | I/O, bus timing, electrical faults, integration errors | Out of scope |

## Back-to-back testing

The same inputs go through three implementations, and their outputs must agree:

| Pair | How | Where |
|---|---|---|
| C code and Python reference | Live, on a boundary grid of 504 inputs and 200 random timed sequences | `tests/test_back_to_back.py` |
| Simulink model and Python reference | Model outputs stored by MATLAB, replayed through the reference in CI | `matlab/results/mil_results.csv`, `tests/test_back_to_back.py` |

ISO 26262-6 lists back-to-back comparison between model and code as a method for software unit and integration verification.

The C code here is written by hand. It is not generated from the model, so agreement between the two is evidence that both follow the same requirements, not a check of a code generator.

## Structural coverage by level

| Artifact | Metric | Tool |
|---|---|---|
| Simulink model | Decision, condition, MC/DC | Simulink Coverage |
| C code | Branch | gcov, gcovr |
| Python reference | Branch | coverage.py |

MC/DC is measured on the model only. gcc can measure condition coverage from version 14 on; the CI image ships an older one.

## Mapping to Automotive SPICE

| Process | Topic | Artifact here |
|---|---|---|
| SWE.1 | Software requirements analysis | `requirements/aeb_requirements.md` |
| SWE.3 | Detailed design and unit construction | `matlab/aeb_model.slx`, `src/c/aeb.c`, `src/aeb.py` |
| SWE.4 | Software unit verification | `testcases/`, `tests/`, coverage, mutation report, static analysis |
| SWE.5 | Software integration test | Not applicable to a single unit |
| SWE.6 | Software qualification test | Not applicable; no integrated software |

Traceability between SWE.1 and SWE.4 is the matrix in `requirements/rtm.csv`.
