"""Runs every sequence of testcases/aeb_sequences.csv through AebController.

A sequence is a list of timed steps; the expected action is checked after each.
"""

import pytest

from aeb import AebController
from tools.testcases import load_sequences

SEQUENCES = load_sequences()


@pytest.mark.regression
@pytest.mark.skipif(not SEQUENCES, reason="no sequence test cases designed yet (REQ-04)")
@pytest.mark.parametrize("sequence", [pytest.param(s, id=s.tc_id) for s in SEQUENCES] or [None])
def test_sequence(sequence):
    controller = AebController()
    for number, step in enumerate(sequence.steps, start=1):
        actual = controller.update(
            step.speed_kph, step.obstacle_m, step.sensor_age_ms, step.dt_ms
        )
        assert actual.value == step.expected, f"{sequence.tc_id} step {number}"
