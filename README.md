# automotive-sw-qa

Automotive Software QA study project — 8 weeks, covering the full QA lifecycle for an AEB-lite system.

![tests](https://github.com/eungyun-im/automotive-sw-qa/actions/workflows/test.yml/badge.svg)

## What this is

An end-to-end QA portfolio built around **AEB-lite** (Automatic Emergency Braking, simplified):  
brake at ≥30 km/h with obstacle within 20 m, fault on sensor timeout >200 ms.

The system serves as a single thread through every QA discipline in the curriculum —  
requirements traceability → test case design → defect tracking → pytest + CI →  
API testing → CAN/UDS → SW testing (MIL/SIL/HIL) → AI model QA.

## Scope

| System under test | Environment |
|---|---|
| `src/aeb.py` (decision logic) | Ubuntu 22.04, ROS 2, MORAI |
| UDS/CAN ECU sim (`sim/ecu_sim.py`) | vcan0 + python-can |
| AI perception models | UFLD, YOLO |

## Structure

```
automotive-sw-qa/
├── requirements/           # Week 1–2: Requirements & RTM
│   ├── aeb_requirements.md
│   └── rtm.csv
├── testcases/              # Week 2–3: Test case design
│   └── aeb_testcases.csv
├── src/
│   └── aeb.py              # AEB-lite decision logic
├── sim/
│   └── ecu_sim.py          # Week 8: UDS ECU simulator (vcan0)
├── tests/
│   ├── conftest.py
│   ├── test_aeb.py         # Week 6: pytest (parametrize, smoke, regression)
│   ├── api/                # Week 7: API testing with requests+pytest
│   └── can/                # Week 8: UDS/CAN testing
├── bug_reports/            # Week 4–5: Defect tracking
│   └── TEMPLATE.md
├── docs/                   # Week 9–11: Standards & reports
│   ├── verification_levels.md
│   ├── hara.md
│   ├── test_plan.md
│   ├── test_report.md
│   └── llm_tc_review.md
├── .github/workflows/
│   └── test.yml            # Week 6: CI (push + PR)
├── pytest.ini
└── requirements.txt
```

## Weekly roadmap

| Week | Dates | Topic |
|---|---|---|
| 1 | 10/12–10/18 | QA overview, V-Model, ISTQB CTFL, requirements + RTM skeleton |
| 2 | 10/19–10/25 | Test case design — 50 TCs, RTM complete |
| 3 | 10/26–11/01 | Defect tracking — Jira, 5 Whys, STAR write-ups |
| 4 | 11/02–11/08 | pytest — parametrize, fixture, conftest, markers |
| 5 | 11/09–11/15 | CI — GitHub Actions, Allure, API testing (Postman + requests) |
| 6 | 11/16–11/22 | CAN/UDS — vcan0, python-can, ECU sim, NRC assertions |
| 7 | 11/23–11/29 | SW testing — MIL/SIL/HIL, S32K144 HILS, ISO 26262, ASPICE |
| 8 | 11/30–12/06 | AI/CV + LLM QA — UFLD, YOLO, LLM-assisted TC review, final report |

## Quick start

```bash
pip install -r requirements.txt
pytest -m "not network and not can" -v
```

## Reference

- ISTQB CTFL v4.0
- ISO 26262 (Functional Safety)
- ASPICE SWE.1–6
