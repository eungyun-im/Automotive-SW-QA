import pytest

# TODO(week 4): one parametrized case per row of testcases/aeb_testcases.csv,
# with the TC ID as the pytest id so results map 1:1 onto the RTM.


@pytest.mark.regression
@pytest.mark.skip(reason="week 4: REQ-01/02 brake decision, TC-01~TC-12")
def test_brake_decision():
    pass


@pytest.mark.smoke
@pytest.mark.skip(reason="week 4: REQ-03 sensor timeout, TC-21~TC-22")
def test_sensor_timeout():
    pass


@pytest.mark.skip(reason="week 4: REQ-05 invalid speed, TC-41~TC-42")
def test_invalid_speed():
    pass
