"""Build the requirements traceability matrix from the test case files.

    python -m tools.rtm            # print the matrix
    python -m tools.rtm --write    # also write requirements/rtm.csv
"""

import argparse
import csv
import io

from tools.testcases import ROOT, load_cases, load_sequences, requirement_ids

RTM_CSV = ROOT / "requirements" / "rtm.csv"


def build():
    by_requirement = {req: [] for req in requirement_ids()}
    unknown = []
    for item in [*load_cases(), *load_sequences()]:
        if item.req_id in by_requirement:
            by_requirement[item.req_id].append(item.tc_id)
        else:
            unknown.append((item.tc_id, item.req_id))
    return by_requirement, unknown


def to_csv(by_requirement):
    out = io.StringIO()
    writer = csv.writer(out, lineterminator="\n")
    writer.writerow(["REQ_ID", "test_case_count", "TC_IDs", "covered"])
    for req, tcs in by_requirement.items():
        writer.writerow([req, len(tcs), " ".join(tcs), "yes" if tcs else "no"])
    return out.getvalue()


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--write", action="store_true", help="write requirements/rtm.csv")
    args = parser.parse_args()
    by_requirement, unknown = build()
    text = to_csv(by_requirement)
    print(text, end="")
    uncovered = [req for req, tcs in by_requirement.items() if not tcs]
    if uncovered:
        print(f"\nNot covered yet: {', '.join(uncovered)}")
    if unknown:
        print(f"\nUnknown requirement IDs: {unknown}")
    if args.write:
        RTM_CSV.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
