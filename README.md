<div align="center">

# automotive-sw-qa

**Requirement-based testing of an automotive safety function,<br>across model, C code and reference, with the test design itself put under measurement.**

[![tests](https://github.com/eungyun-im/automotive-sw-qa/actions/workflows/test.yml/badge.svg)](https://github.com/eungyun-im/automotive-sw-qa/actions/workflows/test.yml)
![C99](https://img.shields.io/badge/C99-00599C?style=flat-square&logo=c&logoColor=white)
![Simulink](https://img.shields.io/badge/Simulink_%2F_Stateflow-0076A8?style=flat-square)
![Python](https://img.shields.io/badge/Python-3.11-3776AB?style=flat-square&logo=python&logoColor=white)
![pytest](https://img.shields.io/badge/pytest-0A9EDC?style=flat-square&logo=pytest&logoColor=white)
![Mutation testing](https://img.shields.io/badge/mutation_testing-in_CI-555555?style=flat-square)
![ISO 26262](https://img.shields.io/badge/ISO_26262-reference-555555?style=flat-square)

[Overview](#overview) · [Requirements](#requirements) · [Test design](#test-design) · [Model, code, reference](#model-code-reference) · [Measuring the tests](#measuring-the-tests) · [Proof and faults](#requirements-proof-and-faults-with-the-matlab-toolchain) · [Layout](#repository-layout) · [Run](#running)

</div>

---

## Overview

The system under test is **AEB-lite**, a simplified Automatic Emergency Braking decision function. It takes vehicle speed, obstacle distance and sensor data age, and returns `BRAKE`, `NO_ACTION` or `FAULT`.

The repository follows one thread from requirement to evidence:

- Test cases are **designed in CSV files**, traced to requirements. Code only executes them.
- The same test cases run on three implementations of the function: a **Simulink/Stateflow model**, **C code**, and a **Python reference**. Their outputs are compared back to back.
- The test design is then measured: which code it executes (coverage, up to MC/DC on the model) and which code changes it would notice (mutation testing).

> **Status:** the three implementations, the test runner, the traceability matrix, the mutation tool and the static analysis are in place and run in CI. The test case list is a starter set of 12. Extending it, covering REQ-04, and writing the defect and test reports are open.

```mermaid
flowchart LR
    R[Requirements<br>REQ-01 to REQ-05] --> T[Test cases<br>CSV, one ID each]
    T --> M[Simulink model<br>MIL]
    T --> C[C code<br>SIL]
    T --> P[Python reference<br>SIL]
    M <-. back to back .-> P
    C <-. back to back .-> P
    T --> X[Mutation testing]
    X -. surviving mutant = gap in the design .-> T
```

## Requirements

| ID | Condition | Output |
|---|---|---|
| REQ-01 | Speed ≥ 30 km/h, obstacle ≤ 20 m, sensor data valid | `BRAKE` |
| REQ-02 | Speed < 30 km/h | `NO_ACTION` |
| REQ-03 | Sensor data age ≥ 200 ms | `FAULT` |
| REQ-04 | In `FAULT`, inputs healthy for 1 s | back to `NORMAL` |
| REQ-05 | Speed outside 0 to 250 km/h | `FAULT` |

Full spec and design decisions: [`requirements/aeb_requirements.md`](requirements/aeb_requirements.md)

```mermaid
stateDiagram-v2
    [*] --> NORMAL
    NORMAL --> FAULT: stale sensor or invalid speed
    FAULT --> FAULT: fault again (timer restarts)
    FAULT --> NORMAL: healthy for 1000 ms
```

While latched in `FAULT`, the output stays `FAULT` even when the inputs would otherwise call for `BRAKE`.

## Test design

| Technique | Applied to | Example |
|---|---|---|
| Equivalence partitioning | Speed and distance ranges | below 0 · 0 to 30 · 30 to 250 · above 250 km/h |
| Boundary value analysis | Every threshold | 29.9 / 30.0 / 30.1 km/h · 20.0 / 20.1 m · 199 / 200 ms |
| Decision table | REQ-01, 02, 05 | see below |
| State transition | REQ-03, 04 | `NORMAL` ↔ `FAULT` as timed sequences |

**Decision table**

| | R1 | R2 | R3 | R4 |
|---|:-:|:-:|:-:|:-:|
| Speed in valid range | N | Y | Y | Y |
| Speed ≥ 30 km/h | – | N | Y | Y |
| Obstacle ≤ 20 m | – | – | N | Y |
| **Output** | `FAULT` | `NO_ACTION` | `NO_ACTION` | `BRAKE` |

The test cases live in two files, described in [`testcases/README.md`](testcases/README.md):

- [`aeb_testcases.csv`](testcases/aeb_testcases.csv): one row per test of the stateless decision.
- [`aeb_sequences.csv`](testcases/aeb_sequences.csv): timed sequences for the fault latch.

Adding a row adds a test on all three implementations. No code changes are needed.

The traceability matrix is generated from these files with `python -m tools.rtm` and stored as [`requirements/rtm.csv`](requirements/rtm.csv). REQ-01, 02, 03 and 05 are covered; REQ-04 has no test case yet. A test case that cites an unknown requirement fails CI.

## Model, code, reference

| Implementation | Level | Where | How the test cases reach it |
|---|---|---|---|
| Simulink model with a Stateflow chart for the fault latch | MIL | [`matlab/`](matlab) | `run_mil.m` simulates one step per test row |
| C99 code | SIL | [`src/c/`](src/c) | pytest calls the compiled library through `ctypes` |
| Python reference | SIL | [`src/aeb.py`](src/aeb.py) | pytest calls it directly |

The model: a MATLAB Function block for the decision, and a Stateflow chart for the fault latch.

<img src="docs/img/simulink-model.png" alt="Simulink model: five inputs, the decide block, the fault_latch chart, two outputs" width="760">

<img src="docs/img/stateflow-fault-latch.png" alt="Stateflow chart with the states NORMAL and FAULT_LATCHED and the two transitions between them" width="560">

**Back-to-back results**

| Comparison | Inputs | Result |
|---|---|---|
| C code vs Python reference | 504-point boundary grid, 200 random timed sequences | identical, checked on every CI run |
| Simulink model vs Python reference | 504 decision cases, 1500 sequence samples generated from the reference | identical (run in MATLAB R2025b) |
| Simulink model vs designed test cases | 12 test cases | 12 passed |

CI has no MATLAB. The model outputs are stored in [`matlab/results/mil_results.csv`](matlab/results/mil_results.csv), and CI replays every stored input through the Python reference, so a model that disagrees with the code still fails the build.

The C code is written by hand, not generated from the model. Agreement between them shows that both follow the same requirements.

**Static analysis of the C code.** The build uses `-Wall -Wextra -Wpedantic -Wconversion -Wshadow -Werror`, and cppcheck gates CI with no findings. A MISRA C:2012 check with the cppcheck addon reports two advisory findings, both documented as deviations in [`docs/static_analysis.md`](docs/static_analysis.md). The addon covers a subset of MISRA and is not a qualified checker.

## Measuring the tests

**Structural coverage** with the 12 starter test cases:

| Artifact | Metric | Result |
|---|---|---|
| Python reference | Branch | 100 % |
| C code | Branch | 100 % (including harness checks for NULL and overflow) |
| Simulink model | Decision | 86.7 % (13 of 15) |
| Simulink model | Condition | 78.6 % (11 of 14) |
| Simulink model | MC/DC | 71.4 % (5 of 7) |

The model numbers are lower because they include the fault latch, which has no designed test case yet, and because MC/DC asks more than branch coverage does. Inputs generated from the reference reach 100 % on all three model metrics, so the gap is in the test design and can be closed.

**Mutation testing** asks a different question. The tool makes one small change to the decision logic at a time (`>=` to `>`, `30.0` to `31.0`, `and` to `or`, a different return value) and reruns the test cases. A change no test notices is a surviving mutant.

```bash
python -m tools.mutation
```

| | |
|---|---|
| Mutants generated | 25 |
| Killed | 23 |
| Survived | 2 |
| Mutation score | 92 % |

Both survivors sit on the same boundary: the upper speed limit can change from `<= 250.0` to `< 250.0`, or from `250.0` to `249.0`, and every test still passes. The set tests 250.1 km/h but never 250.0. Full branch coverage did not reveal that. The mutation report did, and it names the missing test.

The same gap is visible when the test cases are laid against the boundary points of the spec:

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/img/boundary-points-dark.svg">
  <img src="docs/img/boundary-points-light.svg" alt="Boundary points used by the starter test cases: 10 of 15, with 249.9 and 250.0 km/h among the unused ones" width="760">
</picture>

Regenerated from the test case file with `python -m tools.figures`.

Equivalent mutants are not excluded, so the score is a lower bound. The report is regenerated on every CI run.

## Requirements, proof and faults with the MATLAB toolchain

The model is also run through four MATLAB tools, from requirement to evidence. Everything below is scripted in `matlab/`, runs on R2025b, and the results are committed (CI has no MATLAB). Each result names what it does not show.

### Requirements, tests and traceability (Requirements Toolbox, Simulink Test)

`build_requirements.m` creates the requirement set from the table in `requirements/aeb_requirements.md` and links each requirement to the model element that implements it. `build_tests.m` turns every designed test case of `testcases/*.csv` into a Simulink Test case with a baseline made from the `expected` column (not from the model), linked to its requirement. `run_tests.m` runs them and reads the status back from the requirement set:

| Requirement | Implemented by | Verifying tests | Passed | Status |
|---|---|---|---|---|
| REQ-01 | `decide` | 6 | 6 | Passed |
| REQ-02 | `decide` | 2 | 2 | Passed |
| REQ-03 | `decide` | 2 | 2 | Passed |
| REQ-04 | `fault_latch` | 0 | 0 | **Missing** |
| REQ-05 | `decide` | 2 | 2 | Passed |

REQ-04 (fault recovery) has an implementation and no test case: `testcases/aeb_sequences.csv` is still empty. The traceability result shows it as a gap rather than hiding it.

### What a requirement change touches (`change_impact.m`)

When a requirement changes, the toolbox marks the links whose destination changed. The comparison below puts that next to the test cases that are actually stale, found by recomputing the expected result under the changed requirement. It runs on temporary copies of the requirement set.

| Change | Marked by links | Stale | Missed |
|---|---|---|---|
| S1 brake speed 30 to 35 (REQ-01, REQ-02 updated) | 8 | 2 | 0 |
| S2 brake speed 30 to 25 (REQ-01, REQ-02 updated) | 8 | 1 | 0 |
| S3 detection range 20 to 15 m | 6 | 1 | 0 |
| S4 sensor timeout 200 to 250 ms | 2 | 1 | 0 |
| S5 speed limit 250 to 120 km/h | 2 | 0 | 0 |
| S6 brake speed 30 to 25, REQ-02 not updated | 6 | 1 | **1** |

The links find every stale test here, and mark many that are not stale (at most half of what is marked is stale). In S6, where one requirement is edited and the one that shares the threshold is forgotten, the test that became stale (TC-11) is linked to the other requirement and is not marked. The same two effects, too many marked tests and a miss when the stale test is linked elsewhere, were measured on synthetic suites in [testcase-staleness](https://github.com/eungyun-im/testcase-staleness).

### Proof and generated tests (Simulink Design Verifier)

`design_verifier_tests.m` asks for test cases that reach every decision, condition and MC/DC objective, then replays them on the model and measures the coverage with Simulink Coverage. Three generated test cases reach all 43 objectives:

| Test set | Cases | Decision | Condition | MC/DC |
|---|---|---|---|---|
| Designed (starter set) | 12 | 86.7 % | 78.6 % | 71.4 % |
| Generated by Design Verifier | 3 (sequences) | 100 % | 100 % | 100 % |

The generated sequences also exercise the fault latch (REQ-04), which no designed test case does yet. They are inputs, not expected results: nobody has said what the right output is, so they are a coverage tool and not a replacement for the test design.

`design_verifier_properties.m` states the requirements as properties and asks for a proof over all inputs instead of a list of cases. All seven are proven on the model (REQ-01 both ways, REQ-02, REQ-03, REQ-05, "the fault latch never hides a fault", and the output range). Then six defects are written into the decision, one at a time, and the proof is run again:

| Defect | Falsified, with this input | Designed test cases that fail |
|---|---|---|
| Sensor timeout `>=` becomes `>` | speed 30, sensor age 200 ms | 1 |
| Detection range `<=` becomes `<` | speed 30, obstacle 20 m | 1 |
| Brake speed `>=` becomes `>` | speed 30 km/h | 1 |
| Speed limit 250 becomes 255 | speed 251 km/h | 1 |
| Brake check before the sensor check | speed 30, sensor age 200 ms | 1 |
| An obstacle closer than 1 m is ignored | obstacle 0 m | **0** |

The five defects at a boundary are also caught by the designed tests, because the starter set is built around the boundaries. The sixth sits in the middle of the input range: no designed test case fails, and the proof finds it at once. The inputs of the proof are restricted to physical ranges (set on the inports); a proof holds inside these ranges only.

### Faults on the inputs (Simulink Fault Analyzer)

`fault_analysis.m` injects ten faults, each alone (a signal stuck at a value or scaled), and runs the 12 designed test cases and the generated sequences with and without the fault. The effect is the difference of the two outputs:

| Fault | No effect | Safe deviation (FAULT) | Missed brake | Spurious brake |
|---|---|---|---|---|
| speed stuck at 0 | 19 | 0 | 6 | 0 |
| speed reads half | 20 | 0 | 6 | 1 |
| speed reads 1.5 times | 30 | 0 | 0 | 1 |
| obstacle flag stuck at "none" | 25 | 0 | 6 | 0 |
| obstacle flag stuck at "detected" | 29 | 0 | 0 | 2 |
| distance reads twice | 30 | 0 | 1 | 0 |
| distance stuck at 0 m | 28 | 0 | 0 | 3 |
| sensor age stuck at 0 | 30 | 0 | 0 | 1 |
| sensor age reads ten times | 18 | 13 | 0 | 0 |
| time step stuck at 0 | 27 | 4 | 0 | 0 |

(31 stimuli per fault.) Only the two faults on the sensor age and the time step lead to `FAULT`; a stuck speed or obstacle flag changes the decision to a missed or spurious brake that the function itself does not detect. This function has no plausibility check on its inputs, and the table is how that shows. A stuck sensor age is the dangerous one: stale data looks fresh, and `BRAKE` is issued where `FAULT` is required. How severe each effect is, how often it occurs and whether a driver can control it is the hazard analysis (`docs/hara.md`), which is not done.

## Repository layout

```
automotive-sw-qa/
├── requirements/
│   ├── aeb_requirements.md   Requirement spec and design decisions
│   └── rtm.csv               Traceability matrix (generated)
├── testcases/                Test design: CSV files and their format
├── matlab/
│   ├── build_model.m         Builds the Simulink model from a script
│   ├── run_mil.m             Simulates the model with the test cases, measures coverage
│   ├── aeb_model.slx         The model
│   └── results/              Stored model outputs and coverage summary
├── src/
│   ├── c/aeb.c, aeb.h        C implementation
│   └── aeb.py                Python reference
├── tests/
│   ├── test_aeb.py           Test cases on the Python reference
│   ├── test_aeb_c.py         Test cases on the C code
│   ├── test_aeb_sequences.py Timed sequences
│   ├── test_back_to_back.py  C vs Python, model vs Python
│   ├── test_controller.py    Implementation checks for the fault latch
│   └── test_traceability.py  Consistency of test cases and requirements
├── tools/
│   ├── caeb.py               Builds the C library and wraps it for Python
│   ├── model_check.py        Generates check inputs for the model
│   ├── rtm.py                Traceability matrix
│   ├── mutation.py           Mutation testing
│   └── testcases.py          CSV loading
├── bug_reports/              Defect report template
├── docs/                     Test plan, verification levels, static analysis, HARA, test report
└── .github/workflows/        CI: tests, coverage, static analysis, RTM, mutation report
```

## Running

Python and C (needs gcc; the C tests are skipped without it):

```bash
pip install -r requirements.txt
pytest -v --cov=src --cov-branch
```

Model in the loop (needs MATLAB with Simulink, Stateflow and Simulink Coverage), from the `matlab` folder:

```matlab
run_mil
```

| Marker | Selects |
|---|---|
| `smoke` | High-priority test cases |
| `regression` | Every designed test case |
| `c` | Tests that run the C code |

## Roadmap

**Core**

- [x] AEB-lite decision logic and fault latch in Python, C and Simulink/Stateflow
- [x] Data-driven tests, one pytest ID per test case
- [x] Back-to-back comparison of the three implementations
- [x] Generated traceability matrix
- [x] Coverage, mutation testing and static analysis in CI
- [x] Test plan
- [ ] Full test case list from the four design techniques, with every mutant killed or explained and MC/DC of the model closed
- [ ] REQ-04 sequence test cases
- [ ] Defect reports with reproduction steps and root cause
- [ ] Test report

**Later**

- [ ] C code generated from the model with Embedded Coder, compared with the hand-written code
- [ ] HARA traced to safety requirements and tests
- [ ] API tests against a mock vehicle control service

## Standards referenced

ISTQB CTFL v4.0 · ISO 26262-6 · MISRA C:2012 · Automotive SPICE (SWE.1, SWE.3, SWE.4)

## Related

- [ecu-quality-gate](https://github.com/eungyun-im/ecu-quality-gate): release gate for ECU software with UDS diagnostics, network and security checks
- [llm-testcase-review](https://github.com/eungyun-im/llm-testcase-review): execution-based evaluation of LLM-written test cases for this same function
