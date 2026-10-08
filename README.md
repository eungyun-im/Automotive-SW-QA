# automotive-sw-qa

End-to-end software QA for an automotive safety function, from requirements to an automated regression suite.

![tests](https://github.com/eungyun-im/automotive-sw-qa/actions/workflows/test.yml/badge.svg)

## Overview

The system under test is **AEB-lite**, a simplified Automatic Emergency Braking decision function:

- Brake when speed is at least 30 km/h and an obstacle is within 20 m.
- Report a fault when sensor data is 200 ms old or older.
- Report a fault when speed is outside 0 to 250 km/h.

Every artifact in this repository traces back to those requirements: the test cases, the automated tests, the defect reports, and the final test report.

> Work in progress. The structure, requirements, and test case list are in place. The implementation and the automated tests are being filled in.

## What it covers

| Area | Artifact |
|---|---|
| Requirements and traceability | [`requirements/`](requirements) — requirement spec and RTM |
| Test design | [`testcases/`](testcases) — equivalence classes, boundary values, decision tables, state transitions |
| Unit and regression testing | [`tests/test_aeb.py`](tests/test_aeb.py) — pytest, one test ID per test case |
| Continuous integration | [`.github/workflows/test.yml`](.github/workflows/test.yml) — runs on every push and pull request |
| API testing | [`tests/api/`](tests/api) — requests + pytest |
| In-vehicle network diagnostics | [`sim/ecu_sim.py`](sim/ecu_sim.py), [`tests/can/`](tests/can) — UDS over a virtual CAN bus |
| Defect management | [`bug_reports/`](bug_reports) — reproducible reports with root cause analysis |
| Functional safety and process | [`docs/`](docs) — verification levels, HARA, test plan, test report |
| AI-assisted testing | [`docs/llm_tc_review.md`](docs/llm_tc_review.md) — review of LLM-generated test cases |

## Repository layout

```
automotive-sw-qa/
├── requirements/        Requirement spec and traceability matrix
├── testcases/           Test case list
├── src/aeb.py           AEB-lite decision logic
├── sim/ecu_sim.py       Virtual UDS ECU (vcan0)
├── tests/
│   ├── test_aeb.py      Decision logic tests
│   ├── api/             API tests
│   └── can/             UDS tests
├── bug_reports/         Defect reports
├── docs/                Test plan, test report, safety analysis
└── .github/workflows/   CI
```

## Running the tests

```bash
pip install -r requirements.txt
pytest -m "not network and not can" -v
```

The `network` tests need internet access. The `can` tests need a Linux virtual CAN interface (`vcan0`) with `sim/ecu_sim.py` running.

## Standards referenced

ISTQB CTFL v4.0 · ISO 26262 · Automotive SPICE (SWE.1 to SWE.6) · ISO 14229 (UDS)
