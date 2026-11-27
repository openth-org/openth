import os

from corsixth_mp import machine


def test_memory_in_use_counts_what_is_not_available(tmp_path):
    meminfo = tmp_path / "meminfo"
    meminfo.write_text("MemTotal:        4000000 kB\nMemFree:          100000 kB\n"
                       "MemAvailable:     1000000 kB\nSwapTotal:       4194300 kB\n")
    assert machine.mem_percent(str(meminfo)) == 75


def test_memory_is_left_out_without_meminfo(tmp_path):
    assert machine.mem_percent(str(tmp_path / "missing")) is None
    old = tmp_path / "old"
    old.write_text("MemTotal: 4000000 kB\nMemFree: 100000 kB\n")  # kernels before 3.14
    assert machine.mem_percent(str(old)) is None


def test_cpu_is_the_load_average_per_core(monkeypatch):
    monkeypatch.setattr(os, "getloadavg", lambda: (3.0, 2.0, 1.0), raising=False)
    monkeypatch.setattr(os, "cpu_count", lambda: 4)
    assert machine.cpu_percent() == 75
    monkeypatch.setattr(os, "getloadavg", lambda: (6.0, 2.0, 1.0), raising=False)
    assert machine.cpu_percent() == 150  # processes waiting for a core


def test_cpu_is_left_out_without_a_load_average(monkeypatch):
    monkeypatch.delattr(os, "getloadavg", raising=False)
    assert machine.cpu_percent() is None


def test_disk_is_a_whole_percent(tmp_path):
    value = machine.disk_percent(str(tmp_path))
    assert isinstance(value, int) and 0 <= value <= 100
    assert machine.disk_percent(str(tmp_path / "missing")) is None


def test_readings_are_kept_for_a_few_seconds(monkeypatch):
    calls = []
    monkeypatch.setattr(machine, "cpu_percent", lambda: calls.append(1) or 10)
    monkeypatch.setattr(machine, "mem_percent", lambda: 20)
    monkeypatch.setattr(machine, "disk_percent", lambda: 30)
    monkeypatch.setattr(machine, "_cached", {})
    assert machine.load() == {"cpu": 10, "mem": 20, "disk": 30}
    assert machine.load() == {"cpu": 10, "mem": 20, "disk": 30}
    assert len(calls) == 1
    monkeypatch.setattr(machine, "_cached_at", machine._cached_at - machine.CACHE_SECONDS)
    machine.load()
    assert len(calls) == 2
