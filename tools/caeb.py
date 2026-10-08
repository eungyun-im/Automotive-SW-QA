"""Build the C implementation and call it from Python.

    python -m tools.caeb            # build build/libaeb.so
    python -m tools.caeb --coverage # build with gcov instrumentation

The Python wrapper mirrors src/aeb.py so the same test cases run on both.
"""

import argparse
import ctypes
import shutil
import subprocess

from tools.testcases import ROOT

SOURCE = ROOT / "src" / "c" / "aeb.c"
BUILD_DIR = ROOT / "build"
LIBRARY = BUILD_DIR / "libaeb.so"
ACTIONS = ("NO_ACTION", "BRAKE", "FAULT")
STATES = ("NORMAL", "FAULT")
WARNINGS = ["-Wall", "-Wextra", "-Wpedantic", "-Wconversion", "-Wshadow", "-Werror"]


def compiler():
    return shutil.which("gcc")


def build(coverage=False):
    """Compile src/c/aeb.c into a shared library and return its path."""
    BUILD_DIR.mkdir(exist_ok=True)
    command = [compiler(), "-std=c99", *WARNINGS, "-O0", "-g", "-fPIC", "-shared"]
    if coverage:
        command.append("--coverage")
    command += [str(SOURCE), "-o", str(LIBRARY)]
    subprocess.run(command, check=True, cwd=BUILD_DIR)
    return LIBRARY


class _Controller(ctypes.Structure):
    _fields_ = [("state", ctypes.c_int), ("healthy_ms", ctypes.c_uint32)]


def _inputs(speed_kph, obstacle_m, sensor_age_ms):
    detected = obstacle_m is not None
    return (
        ctypes.c_float(speed_kph),
        ctypes.c_bool(detected),
        ctypes.c_float(obstacle_m if detected else 0.0),
        ctypes.c_uint32(sensor_age_ms),
    )


class CAeb:
    """The C library behind the same interface as the Python implementation."""

    def __init__(self, library_path=LIBRARY):
        self._lib = ctypes.CDLL(str(library_path))
        self._lib.aeb_decide.restype = ctypes.c_int
        self._lib.aeb_controller_update.restype = ctypes.c_int
        self._lib.aeb_controller_init.restype = None

    def decide(self, speed_kph, obstacle_m, sensor_age_ms):
        return ACTIONS[self._lib.aeb_decide(*_inputs(speed_kph, obstacle_m, sensor_age_ms))]

    def controller(self):
        return CController(self._lib)


class CController:
    def __init__(self, lib):
        self._lib = lib
        self._state = _Controller()
        lib.aeb_controller_init(ctypes.byref(self._state))

    @property
    def state(self):
        return STATES[self._state.state]

    def update(self, speed_kph, obstacle_m, sensor_age_ms, dt_ms):
        code = self._lib.aeb_controller_update(
            ctypes.byref(self._state),
            *_inputs(speed_kph, obstacle_m, sensor_age_ms),
            ctypes.c_uint32(dt_ms),
        )
        return ACTIONS[code]


def main():
    parser = argparse.ArgumentParser(description="Build the C implementation.")
    parser.add_argument("--coverage", action="store_true", help="instrument for gcov")
    args = parser.parse_args()
    print(build(coverage=args.coverage))


if __name__ == "__main__":
    main()
