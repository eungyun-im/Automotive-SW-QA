# Verification levels

Where this project sits among the usual levels of automotive software verification.

| Level | What runs | What it catches | In this project |
|---|---|---|---|
| MIL (model in the loop) | The control model against a plant model | Errors in the control concept | Not used. The logic is hand-written code, not a model. |
| SIL (software in the loop) | The production code on a PC | Logic errors, boundary errors, interface errors | **This project.** `src/aeb.py` is executed directly by pytest. |
| PIL (processor in the loop) | The code compiled for the target processor | Compiler, data type and timing differences | Out of scope |
| HIL (hardware in the loop) | The real ECU against a simulated vehicle | I/O, bus timing, electrical faults, integration errors | Out of scope |

## Mapping to Automotive SPICE

| Process | Topic | Artifact here |
|---|---|---|
| SWE.1 | Software requirements analysis | `requirements/aeb_requirements.md` |
| SWE.3 | Detailed design and unit construction | `src/aeb.py` |
| SWE.4 | Software unit verification | `testcases/`, `tests/`, coverage, mutation report |
| SWE.5 | Software integration test | Not applicable to a single unit |
| SWE.6 | Software qualification test | Not applicable; no integrated software |

Traceability between SWE.1 and SWE.4 is the matrix in `requirements/rtm.csv`.
