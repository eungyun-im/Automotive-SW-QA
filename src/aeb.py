from enum import Enum


class Action(Enum):
    NO_ACTION = "NO_ACTION"
    BRAKE = "BRAKE"
    FAULT = "FAULT"


SPEED_MIN, SPEED_MAX = 0.0, 250.0
BRAKE_SPEED_KPH = 30.0
DETECT_RANGE_M = 20.0
SENSOR_TIMEOUT_MS = 200


def decide(speed_kph, obstacle_m, sensor_age_ms):
    """REQ-01~03, 05. obstacle_m is None when nothing is detected."""
    # TODO(week 4): implement against requirements/aeb_requirements.md
    raise NotImplementedError
