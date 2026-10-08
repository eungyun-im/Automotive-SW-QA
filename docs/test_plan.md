# Test Plan

## 1. Purpose and scope

Verify that the AEB-lite decision logic meets REQ-01 to REQ-05 in all three implementations: the Simulink model (`matlab/aeb_model.slx`), the C code (`src/c/aeb.c`) and the Python reference (`src/aeb.py`).

## 2. Test items

| In scope | Out of scope |
|---|---|
| `decide()`: stateless decision for one sample | Sensor signal processing |
| `AebController`: fault latch and recovery | Brake actuation and vehicle dynamics |
| | Timing on target hardware |

## 3. Approach

- **Level:** unit test of the decision logic, driven by requirement-based test cases, at MIL (model) and SIL (C and Python).
- **Back-to-back:** the three implementations must give the same output for the same input.
- **Design techniques:** equivalence partitioning, boundary value analysis, decision table, state transition.
- **Automation:** every row of `testcases/*.csv` is executed by pytest. The test case ID is the pytest ID.
- **Adequacy of the test design:** measured two ways. Structural coverage shows which code the cases execute (branch on the code, decision, condition and MC/DC on the model). Mutation testing shows which code changes the cases would notice.
- **Static analysis:** compiler warnings as errors and cppcheck on the C code, with a MISRA C:2012 check as information.

## 4. Environment

Python 3.11, pytest, pytest-cov, gcc, gcovr and cppcheck on GitHub Actions (`ubuntu-latest`) for every push and pull request. MATLAB R2025b with Simulink, Stateflow and Simulink Coverage for the model, run locally with results committed.

## 5. Entry and exit criteria

| | Criterion |
|---|---|
| Entry | Requirements reviewed, test cases traced to requirements |
| Exit | Every requirement has at least one executed test case |
| Exit | All test cases pass |
| Exit | Branch coverage of the Python and C code is 100 %, and MC/DC of the model is 100 % |
| Exit | Model, C code and Python reference agree on every test input |
| Exit | Every surviving mutant is either killed by a new test case or recorded as equivalent |

## 6. Deliverables

Test case files, traceability matrix (`requirements/rtm.csv`), mutation report, defect reports, test report.

## 7. Risks

| Risk | Mitigation |
|---|---|
| A wrong expected result in a test case hides a defect | Expected results are derived from the requirement text, not from the code |
| Coverage is high but boundaries are untested | Mutation testing exposes untested boundaries |
| REQ-04 timing is tested only in simulated time | Stated as a limit; target timing is out of scope |
