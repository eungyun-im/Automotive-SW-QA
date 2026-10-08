"""Generate check sequences for the Simulink model from the Python reference.

    python -m tools.model_check build/model_check

Writes aeb_testcases.csv and aeb_sequences.csv with expected results computed
by src/aeb.py: a boundary grid for the decision block and random timed
sequences for the fault latch. Run them in MATLAB with

    run_mil(Cases="...", Sequences="...", Results="...")

Every sample must pass. This checks the model itself; the designed test cases
in testcases/ check the requirements.
"""

import argparse
import csv
import itertools
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))

from aeb import AebController, decide  # noqa: E402

SPEEDS = [-0.1, 0.0, 0.1, 15.0, 29.9, 30.0, 30.1, 100.0, 249.9, 250.0, 250.1, 300.0]
OBSTACLES = [None, 0.0, 10.0, 19.9, 20.0, 20.1, 50.0]
AGES = [0, 50, 199, 200, 201, 1000]
GRID = list(itertools.product(SPEEDS, OBSTACLES, AGES))
DT_CHOICES = [1, 10, 100, 500, 999, 1000]


def _obstacle(value):
    return "" if value is None else value


def write(directory, sequences=60, steps=25, seed=20261008):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    with open(directory / "aeb_testcases.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(
            ["TC_ID", "REQ_ID", "speed_kph", "obstacle_m", "sensor_age_ms", "expected", "priority", "technique"]
        )
        for number, (speed, obstacle, age) in enumerate(GRID, start=1):
            expected = decide(speed, obstacle, age).value
            writer.writerow([f"G-{number:03d}", "CHECK", speed, _obstacle(obstacle), age, expected, "High", "grid"])

    rng = random.Random(seed)
    with open(directory / "aeb_sequences.csv", "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["TC_ID", "REQ_ID", "dt_ms", "speed_kph", "obstacle_m", "sensor_age_ms", "expected"])
        for number in range(1, sequences + 1):
            controller = AebController()
            for _ in range(steps):
                speed, obstacle, age = rng.choice(GRID)
                dt_ms = rng.choice(DT_CHOICES)
                expected = controller.update(speed, obstacle, age, dt_ms).value
                writer.writerow([f"S-{number:03d}", "CHECK", dt_ms, speed, _obstacle(obstacle), age, expected])
    return len(GRID), sequences * steps


def main():
    parser = argparse.ArgumentParser(description="Generate check sequences for the Simulink model.")
    parser.add_argument("directory")
    args = parser.parse_args()
    decisions, samples = write(args.directory)
    print(f"{decisions} decision cases and {samples} sequence samples written to {args.directory}")


if __name__ == "__main__":
    main()
