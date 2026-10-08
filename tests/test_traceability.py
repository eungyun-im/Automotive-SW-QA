"""Consistency of the test case files with the requirement spec."""

from tools.mutation import generate, SOURCE
from tools.rtm import build
from tools.testcases import load_cases, load_sequences

VALID_EXPECTED = {"BRAKE", "NO_ACTION", "FAULT"}


def test_test_case_ids_are_unique():
    ids = [c.tc_id for c in load_cases()] + [s.tc_id for s in load_sequences()]
    assert len(ids) == len(set(ids))


def test_every_test_case_cites_a_known_requirement():
    _, unknown = build()
    assert unknown == []


def test_expected_values_are_defined_outputs():
    assert {c.expected for c in load_cases()} <= VALID_EXPECTED


def test_mutants_are_generated():
    assert len(generate(SOURCE.read_text(encoding="utf-8"))) > 10
