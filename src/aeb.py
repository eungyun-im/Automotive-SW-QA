from enum import Enum


class Action(Enum):
    NO_ACTION = "NO_ACTION"
    BRAKE = "BRAKE"
    FAULT = "FAULT"


class State(Enum):
    NORMAL = "NORMAL"
    FAULT = "FAULT"


SPEED_MIN, SPEED_MAX = 0.0, 250.0
BRAKE_SPEED_KPH = 30.0
DETECT_RANGE_M = 20.0
SENSOR_TIMEOUT_MS = 200
RECOVERY_MS = 1000


def decide(speed_kph, obstacle_m, sensor_age_ms):
    """Stateless decision for one sample (REQ-01, 02, 03, 05).

    obstacle_m is None when nothing is detected.
    """
    if not (SPEED_MIN <= speed_kph <= SPEED_MAX):
        return Action.FAULT
    if sensor_age_ms >= SENSOR_TIMEOUT_MS:
        return Action.FAULT
    if (
        speed_kph >= BRAKE_SPEED_KPH
        and obstacle_m is not None
        and obstacle_m <= DETECT_RANGE_M
    ):
        return Action.BRAKE
    return Action.NO_ACTION


class AebController:
    """Adds the fault latch and recovery of REQ-04 on top of decide()."""

    def __init__(self):
        self.state = State.NORMAL
        self.healthy_ms = 0

    def update(self, speed_kph, obstacle_m, sensor_age_ms, dt_ms):
        """Advance by dt_ms with the given inputs and return the commanded action."""
        raw = decide(speed_kph, obstacle_m, sensor_age_ms)
        if raw is Action.FAULT:
            self.state = State.FAULT
            self.healthy_ms = 0
            return Action.FAULT
        if self.state is State.FAULT:
            self.healthy_ms += dt_ms
            if self.healthy_ms < RECOVERY_MS:
                return Action.FAULT
            self.state = State.NORMAL
            self.healthy_ms = 0
        return raw
