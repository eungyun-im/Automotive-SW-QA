import pytest

pytestmark = pytest.mark.network

# TODO(week 5): requests + pytest against a public practice API
# (200 / 201 / 404 paths), kept out of PR runs with -m "not network".


@pytest.mark.skip(reason="week 5: API tests")
def test_get_post_ok():
    pass
