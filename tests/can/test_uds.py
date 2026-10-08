import pytest

pytestmark = pytest.mark.can

# TODO(week 6): needs vcan0 and sim/ecu_sim.py running.
# Positive response 0x62, NRC 0x31 (unknown DID), NRC 0x13 (wrong length).


@pytest.mark.skip(reason="week 6: UDS tests")
def test_read_did_positive():
    pass
