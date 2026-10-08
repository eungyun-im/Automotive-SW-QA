"""Load the hand-designed test cases from testcases/*.csv."""

import csv
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

ROOT = Path(__file__).resolve().parent.parent
CASES_CSV = ROOT / "testcases" / "aeb_testcases.csv"
SEQUENCES_CSV = ROOT / "testcases" / "aeb_sequences.csv"
REQUIREMENTS_MD = ROOT / "requirements" / "aeb_requirements.md"


@dataclass(frozen=True)
class Case:
    tc_id: str
    req_id: str
    speed_kph: float
    obstacle_m: Optional[float]
    sensor_age_ms: int
    expected: str
    priority: str
    technique: str


@dataclass(frozen=True)
class Step:
    dt_ms: int
    speed_kph: float
    obstacle_m: Optional[float]
    sensor_age_ms: int
    expected: str


@dataclass(frozen=True)
class Sequence:
    tc_id: str
    req_id: str
    steps: tuple


def _optional_float(text):
    text = text.strip()
    return float(text) if text else None


def load_cases(path=CASES_CSV):
    with open(path, newline="", encoding="utf-8") as f:
        return [
            Case(
                tc_id=row["TC_ID"].strip(),
                req_id=row["REQ_ID"].strip(),
                speed_kph=float(row["speed_kph"]),
                obstacle_m=_optional_float(row["obstacle_m"]),
                sensor_age_ms=int(row["sensor_age_ms"]),
                expected=row["expected"].strip(),
                priority=row["priority"].strip(),
                technique=row["technique"].strip(),
            )
            for row in csv.DictReader(f)
        ]


def load_sequences(path=SEQUENCES_CSV):
    """Rows with the same TC_ID form one sequence, in file order."""
    grouped = {}
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            key = (row["TC_ID"].strip(), row["REQ_ID"].strip())
            grouped.setdefault(key, []).append(
                Step(
                    dt_ms=int(row["dt_ms"]),
                    speed_kph=float(row["speed_kph"]),
                    obstacle_m=_optional_float(row["obstacle_m"]),
                    sensor_age_ms=int(row["sensor_age_ms"]),
                    expected=row["expected"].strip(),
                )
            )
    return [Sequence(tc, req, tuple(steps)) for (tc, req), steps in grouped.items()]


def requirement_ids(path=REQUIREMENTS_MD):
    text = Path(path).read_text(encoding="utf-8")
    return sorted(set(re.findall(r"^\| (REQ-\d+) \|", text, flags=re.MULTILINE)))
