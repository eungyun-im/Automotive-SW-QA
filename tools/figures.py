"""Generate the README figure from the current test case file.

    python -m tools.figures

Writes docs/img/boundary-points-light.svg and -dark.svg.
"""

from tools.svgfig import Figure, save_both
from tools.testcases import ROOT, load_cases

IMG = ROOT / "docs" / "img"

# (label, input, boundary value, resolution, unit)
BOUNDARIES = [
    ("Minimum speed", "speed_kph", 0.0, 0.1, "km/h"),
    ("Brake threshold", "speed_kph", 30.0, 0.1, "km/h"),
    ("Maximum speed", "speed_kph", 250.0, 0.1, "km/h"),
    ("Detection range", "obstacle_m", 20.0, 0.1, "m"),
    ("Sensor timeout", "sensor_age_ms", 200, 1, "ms"),
]
POSITIONS = [("just below", -1), ("at the boundary", 0), ("just above", 1)]


def coverage(cases):
    """For every boundary point: the value and the test cases that use it."""
    rows = []
    for label, name, value, step, unit in BOUNDARIES:
        points = []
        for _, offset in POSITIONS:
            target = round(value + offset * step, 6)
            hits = [
                c.tc_id for c in cases
                if getattr(c, name) is not None and abs(getattr(c, name) - target) < 1e-6
            ]
            points.append((target, hits))
        rows.append((label, unit, points))
    return rows


def boundary_figure(mode, cases):
    rows = coverage(cases)
    total = sum(len(points) for _, _, points in rows)
    covered = sum(1 for _, _, points in rows for _, hits in points if hits)
    fig = Figure(
        760, 404, mode,
        f"The {len(cases)} starter test cases use {covered} of {total} boundary points",
        "Each threshold needs a test just below it, at it, and just above it. A ring is a point no test uses.",
    )
    label_x, columns, top, row_height = 24, (300, 470, 640), 112, 46
    for (heading, _), x in zip(POSITIONS, columns):
        fig.text(x, top - 22, heading, size=12, color="secondary", anchor="middle")
    fig.line(label_x, top - 8, 736, top - 8)
    for index, (label, unit, points) in enumerate(rows):
        y = top + 22 + index * row_height
        fig.text(label_x, y + 1, label, size=13, weight=600)
        boundary_value = points[1][0]
        fig.text(label_x, y + 17, f"{boundary_value:g} {unit}", size=11, color="secondary")
        for (value, hits), x in zip(points, columns):
            if hits:
                fig.dot(x - 44, y, "series1", r=6)
                note = ", ".join(hits[:2]) + (" ..." if len(hits) > 2 else "")
            else:
                fig.add(
                    f'<circle cx="{x - 44:.1f}" cy="{y:.1f}" r="5.5" fill="none" '
                    f'stroke="{fig.color("series2")}" stroke-width="2"/>'
                )
                note = "no test"
            fig.text(x - 30, y - 1, f"{value:g}", size=12, weight=600)
            fig.text(x - 30, y + 14, note, size=11, color="secondary")
        fig.line(label_x, y + 26, 736, y + 26)
    legend_y = top + 22 + len(rows) * row_height + 8
    fig.dot(label_x + 6, legend_y, "series1", r=6)
    fig.text(label_x + 20, legend_y + 4, "used by a test case", size=11, color="secondary")
    fig.add(
        f'<circle cx="{label_x + 176:.1f}" cy="{legend_y:.1f}" r="5.5" fill="none" '
        f'stroke="{fig.color("series2")}" stroke-width="2"/>'
    )
    fig.text(label_x + 190, legend_y + 4, "not used by any test case", size=11, color="secondary")
    return fig


def main():
    cases = load_cases()
    save_both(IMG, "boundary-points", lambda mode: boundary_figure(mode, cases))


if __name__ == "__main__":
    main()
