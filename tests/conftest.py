import pytest


@pytest.fixture
def healthy_sensor_age():
    """Sensor age (ms) well inside the timeout."""
    return 50
