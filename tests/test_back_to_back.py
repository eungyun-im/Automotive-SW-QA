"""Back-to-back tests: the same inputs through different implementations.

Python is the reference. The C code is compared live. The Simulink model is
compared through the results MATLAB wrote to matlab/results/mil_results.csv.
"""

import csv
import itertools
import random

import pytest

from aeb import AebController, decide
from tools.testcases import ROOT

MIL_RESULTS = ROOT / "matlab" / "results" / "mil_results.csv"

SPEEDS = [-0.1, 0.0, 0.1, 15.0, 29.9, 30.0, 30.1, 100.0, 249.9, 250.0, 250.1, 300.0]
OBSTACLES = [None, 0.0, 10.0, 19.9, 20.0, 20.1, 50.0]
AGES = [0, 50, 199, 200, 201, 1000]
GRID = list(itertools.product(SPEEDS, OBSTACLES, AGES))


@pytest.mark.c
def test_c_matches_python_on_the_boundary_grid(c_aeb):
    differences = [
        (inputs, decide(*inputs).value, c_aeb.decide(*inputs))
        for inputs in GRID
        if decide(*inputs).value != c_aeb.decide(*inputs)
    ]
    assert differences == []


@pytest.mark.c
def test_c_controller_matches_python_on_random_sequences(c_aeb):
    rng = random.Random(20261008)
    for _ in range(200):
        python, c = AebController(), c_aeb.controller()
        for step in range(30):
            inputs = rng.choice(GRID)
            dt_ms = rng.choice([1, 10, 100, 500, 999, 1000])
            expected = python.update(*inputs, dt_ms).value
            assert c.update(*inputs, dt_ms) == expected, (step, inputs, dt_ms)
            assert c.state == python.state.value


def _mil_rows():
    if not MIL_RESULTS.exists():
        return []
    with open(MIL_RESULTS, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def _optional(text):
    return float(text) if text.strip() else None


@pytest.mark.skipif(not _mil_rows(), reason="no stored MIL results (run matlab/run_mil.m)")
def test_stored_model_results_match_python():
    """Replays every input the model was simulated with through the Python reference."""
    controllers, differences = {}, []
    for row in _mil_rows():
        inputs = (float(row["speed_kph"]), _optional(row["obstacle_m"]), int(float(row["sensor_age_ms"])))
        if row["kind"] == "decision":
            expected = decide(*inputs).value
        else:
            controller = controllers.setdefault(row["tc_id"], AebController())
            expected = controller.update(*inputs, int(float(row["dt_ms"]))).value
        if row["model_output"] != expected:
            differences.append((row["tc_id"], row["step"], row["model_output"], expected))
    assert differences == []
