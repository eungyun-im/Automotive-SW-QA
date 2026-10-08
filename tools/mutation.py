"""Mutation testing for the AEB decision logic.

Makes small changes to src/aeb.py (one per mutant) and checks whether the
designed test cases notice. A mutant no test notices points at a gap in the
test design.

    python -m tools.mutation            # print the score and the survivors
    python -m tools.mutation --write    # also write reports/mutation.md
"""

import argparse
import ast
import copy
from dataclasses import dataclass
from pathlib import Path

from tools.testcases import ROOT, load_cases

SOURCE = ROOT / "src" / "aeb.py"
REPORT = ROOT / "reports" / "mutation.md"

RELATIONAL = {
    ast.GtE: ast.Gt,
    ast.Gt: ast.GtE,
    ast.LtE: ast.Lt,
    ast.Lt: ast.LtE,
    ast.Eq: ast.NotEq,
    ast.NotEq: ast.Eq,
    ast.Is: ast.IsNot,
    ast.IsNot: ast.Is,
}


@dataclass(frozen=True)
class Mutant:
    mutant_id: str
    kind: str
    lineno: int
    original: str
    mutated: str
    source: str

    @property
    def description(self):
        return f"line {self.lineno}: `{self.original}` -> `{self.mutated}`"


def _names_used(function):
    return {n.id for n in ast.walk(function) if isinstance(n, ast.Name)}


def _sites(tree, function_name):
    """Nodes that may be mutated: the target function and the constants it reads."""
    function = next(
        n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == function_name
    )
    used = _names_used(function)
    in_scope = set(ast.walk(function))
    for node in tree.body:
        if isinstance(node, ast.Assign):
            targets = {n.id for t in node.targets for n in ast.walk(t) if isinstance(n, ast.Name)}
            if targets & used:
                in_scope |= set(ast.walk(node))
    return [i for i, node in enumerate(ast.walk(tree)) if node in in_scope]


def _variants(node):
    """Yield (kind, mutate) pairs; mutate edits a copy of the node in place."""
    if isinstance(node, ast.Compare):
        for i, op in enumerate(node.ops):
            swap = RELATIONAL.get(type(op))
            if swap:
                yield "relational", lambda n, i=i, swap=swap: n.ops.__setitem__(i, swap())
    if isinstance(node, ast.BoolOp):
        swap = ast.Or if isinstance(node.op, ast.And) else ast.And
        yield "logical", lambda n, swap=swap: setattr(n, "op", swap())
    if isinstance(node, ast.Constant) and type(node.value) in (int, float):
        for delta in (1, -1):
            yield "constant", lambda n, d=delta: setattr(n, "value", n.value + d)
    if isinstance(node, ast.Return) and isinstance(node.value, ast.Attribute):
        if isinstance(node.value.value, ast.Name) and node.value.value.id == "Action":
            for member in ("NO_ACTION", "BRAKE", "FAULT"):
                if member != node.value.attr:
                    yield "return", lambda n, m=member: setattr(n.value, "attr", m)


def generate(source_text, function_name="decide"):
    tree = ast.parse(source_text)
    mutants = []
    for index in _sites(tree, function_name):
        node = list(ast.walk(tree))[index]
        for kind, mutate in _variants(node):
            mutated_tree = copy.deepcopy(tree)
            target = list(ast.walk(mutated_tree))[index]
            original = ast.unparse(target)
            mutate(target)
            mutants.append(
                Mutant(
                    mutant_id=f"M{len(mutants) + 1:03d}",
                    kind=kind,
                    lineno=node.lineno,
                    original=original,
                    mutated=ast.unparse(target),
                    source=ast.unparse(mutated_tree),
                )
            )
    return mutants


def load_decide(source_text):
    namespace = {}
    exec(compile(source_text, "<mutant>", "exec"), namespace)
    return namespace["decide"]


def is_killed(mutant, cases):
    decide = load_decide(mutant.source)
    for case in cases:
        try:
            actual = decide(case.speed_kph, case.obstacle_m, case.sensor_age_ms).value
        except Exception:
            return True
        if actual != case.expected:
            return True
    return False


def run(cases=None):
    cases = load_cases() if cases is None else cases
    mutants = generate(SOURCE.read_text(encoding="utf-8"))
    survivors = [m for m in mutants if not is_killed(m, cases)]
    return mutants, survivors


def render(mutants, survivors, case_count):
    killed = len(mutants) - len(survivors)
    lines = [
        "# Mutation report",
        "",
        f"- Test cases: {case_count}",
        f"- Mutants: {len(mutants)}",
        f"- Killed: {killed}",
        f"- Survived: {len(survivors)}",
        f"- Mutation score: {killed / len(mutants):.1%}",
        "",
        "Equivalent mutants (changes that cannot alter behavior) are not excluded,",
        "so the score is a lower bound.",
        "",
    ]
    if survivors:
        lines += ["## Survivors", "", "| ID | Kind | Change |", "|---|---|---|"]
        lines += [f"| {m.mutant_id} | {m.kind} | {m.description} |" for m in survivors]
        lines.append("")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--write", action="store_true", help="write reports/mutation.md")
    args = parser.parse_args()
    cases = load_cases()
    mutants, survivors = run(cases)
    text = render(mutants, survivors, len(cases))
    print(text)
    if args.write:
        REPORT.parent.mkdir(exist_ok=True)
        REPORT.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
