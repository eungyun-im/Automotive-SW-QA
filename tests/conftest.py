import os

import pytest

from tools import caeb


@pytest.fixture(scope="session")
def c_aeb():
    """The C implementation, built once per session. Skipped where gcc is missing."""
    if caeb.compiler() is None:
        pytest.skip("gcc is not available")
    caeb.build(coverage=os.environ.get("AEB_C_COVERAGE") == "1")
    return caeb.CAeb()
