"""Runs every row of testcases/aeb_testcases.csv as one test.

The pytest ID is the test case ID, so a CI result maps onto one RTM row.
"""

import pytest

from aeb import decide
from tools.testcases import load_cases

CASES = load_cases()


def _param(case):
    marks = [pytest.mark.regression]
    if case.priority == "High":
        marks.append(pytest.mark.smoke)
    return pytest.param(case, id=case.tc_id, marks=marks)


@pytest.mark.parametrize("case", [_param(c) for c in CASES])
def test_decision(case):
    actual = decide(case.speed_kph, case.obstacle_m, case.sensor_age_ms)
    assert actual.value == case.expected, f"{case.tc_id} ({case.req_id})"
