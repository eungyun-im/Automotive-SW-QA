"""Runs the same designed test cases against the C implementation."""

import pytest

from tools.testcases import load_cases, load_sequences

CASES = load_cases()
SEQUENCES = load_sequences()

pytestmark = pytest.mark.c


@pytest.mark.regression
@pytest.mark.parametrize("case", [pytest.param(c, id=c.tc_id) for c in CASES])
def test_decision_in_c(c_aeb, case):
    actual = c_aeb.decide(case.speed_kph, case.obstacle_m, case.sensor_age_ms)
    assert actual == case.expected, f"{case.tc_id} ({case.req_id})"


@pytest.mark.regression
@pytest.mark.skipif(not SEQUENCES, reason="no sequence test cases designed yet (REQ-04)")
@pytest.mark.parametrize("sequence", [pytest.param(s, id=s.tc_id) for s in SEQUENCES] or [None])
def test_sequence_in_c(c_aeb, sequence):
    controller = c_aeb.controller()
    for number, step in enumerate(sequence.steps, start=1):
        actual = controller.update(step.speed_kph, step.obstacle_m, step.sensor_age_ms, step.dt_ms)
        assert actual == step.expected, f"{sequence.tc_id} step {number}"


def test_null_controller_is_a_fault(c_aeb):
    import ctypes

    code = c_aeb._lib.aeb_controller_update(
        None, ctypes.c_float(40.0), ctypes.c_bool(True), ctypes.c_float(10.0),
        ctypes.c_uint32(50), ctypes.c_uint32(10),
    )
    assert code == 2


def test_not_a_number_speed_is_a_fault(c_aeb):
    assert c_aeb.decide(float("nan"), 10.0, 50) == "FAULT"


def test_healthy_time_saturates_instead_of_wrapping(c_aeb):
    controller = c_aeb.controller()
    controller.update(40.0, 10.0, 200, 10)  # fault
    assert controller.update(40.0, 10.0, 50, 999) == "FAULT"
    assert controller.update(40.0, 10.0, 50, 0xFFFFFFFF) == "BRAKE"
    assert controller.state == "NORMAL"


def test_init_ignores_a_null_controller(c_aeb):
    assert c_aeb._lib.aeb_controller_init(None) is None
