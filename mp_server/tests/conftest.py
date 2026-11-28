import pytest

from corsixth_mp import server as srv


@pytest.fixture(autouse=True)
def roomy_machine(monkeypatch):
    """Whether one more bot fits (Server._bots_fit) must not depend on how
    busy the machine running the tests is: a big, idle one, unless a test
    gives its server another (server.capacity)."""
    monkeypatch.setattr(srv, "_machine_capacity", lambda: {"cores": 64, "busy": 0.0, "free_mb": 1 << 20})
