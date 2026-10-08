# Test Plan

## 1. Purpose and scope

Verify that the AEB-lite decision logic in `src/aeb.py` meets REQ-01 to REQ-05.

## 2. Test items

| In scope | Out of scope |
|---|---|
| `decide()`: stateless decision for one sample | Sensor signal processing |
| `AebController`: fault latch and recovery | Brake actuation and vehicle dynamics |
| | Timing on target hardware |

## 3. Approach

- **Level:** unit test of the decision logic, driven by requirement-based test cases.
- **Design techniques:** equivalence partitioning, boundary value analysis, decision table, state transition.
- **Automation:** every row of `testcases/*.csv` is executed by pytest. The test case ID is the pytest ID.
- **Adequacy of the test design:** measured two ways. Branch coverage shows which code the cases execute. Mutation testing shows which code changes the cases would notice.

## 4. Environment

Python 3.11, pytest, pytest-cov. GitHub Actions on `ubuntu-latest` for every push and pull request.

## 5. Entry and exit criteria

| | Criterion |
|---|---|
| Entry | Requirements reviewed, test cases traced to requirements |
| Exit | Every requirement has at least one executed test case |
| Exit | All test cases pass |
| Exit | Branch coverage of `src/aeb.py` is 100 % |
| Exit | Every surviving mutant is either killed by a new test case or recorded as equivalent |

## 6. Deliverables

Test case files, traceability matrix (`requirements/rtm.csv`), mutation report, defect reports, test report.

## 7. Risks

| Risk | Mitigation |
|---|---|
| A wrong expected result in a test case hides a defect | Expected results are derived from the requirement text, not from the code |
| Coverage is high but boundaries are untested | Mutation testing exposes untested boundaries |
| REQ-04 timing is tested only in simulated time | Stated as a limit; target timing is out of scope |
