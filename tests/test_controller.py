"""Implementation checks for the REQ-04 fault latch.

These guard the code itself. The requirement-level test cases for REQ-04
belong in testcases/aeb_sequences.csv.
"""

from aeb import Action, AebController, State

HEALTHY = dict(speed_kph=40.0, obstacle_m=10.0, sensor_age_ms=50)
STALE = dict(speed_kph=40.0, obstacle_m=10.0, sensor_age_ms=200)


def test_starts_normal_and_brakes():
    controller = AebController()
    assert controller.update(**HEALTHY, dt_ms=10) is Action.BRAKE
    assert controller.state is State.NORMAL


def test_fault_is_latched_until_recovery_time():
    controller = AebController()
    assert controller.update(**STALE, dt_ms=10) is Action.FAULT
    assert controller.update(**HEALTHY, dt_ms=999) is Action.FAULT
    assert controller.state is State.FAULT
    assert controller.update(**HEALTHY, dt_ms=1) is Action.BRAKE
    assert controller.state is State.NORMAL


def test_new_fault_restarts_recovery_timer():
    controller = AebController()
    controller.update(**STALE, dt_ms=10)
    controller.update(**HEALTHY, dt_ms=900)
    controller.update(**STALE, dt_ms=10)
    assert controller.update(**HEALTHY, dt_ms=900) is Action.FAULT
    assert controller.update(**HEALTHY, dt_ms=100) is Action.BRAKE
