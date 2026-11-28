"""How busy the machine is, for HEALTH and GET /health: whole percents.

  cpu   the one-minute load average per CPU core (over 100 when processes
        wait for a core)
  mem   memory in use: MemTotal minus MemAvailable, of MemTotal
  disk  space used on the disk that holds / (or CORSIXTH_MP_DISK_PATH)

A value that cannot be read on this system (no /proc outside Linux) is
None and left out of the answer. Readings are kept for a few seconds, so
many health checks in a row cost nothing.

capacity() gives the server's bot check the same readings unrounded: the
cores, how many of them are busy (the one-minute load average) and the free
memory in MB (Server._bots_fit).
"""

from __future__ import annotations

import os
import shutil
import time

CACHE_SECONDS = 5.0

_cached: dict[str, int | None] = {}
_cached_at = 0.0


def _percent(part: float, whole: float) -> int | None:
    if whole <= 0:
        return None
    return int(round(part * 100 / whole))


def cpu_percent() -> int | None:
    try:
        load1 = os.getloadavg()[0]
    except (AttributeError, OSError):
        return None
    return _percent(load1, os.cpu_count() or 1)


def _meminfo(meminfo: str = "/proc/meminfo") -> dict[str, int]:
    """/proc/meminfo's values in kB ({} where it cannot be read)."""
    values: dict[str, int] = {}
    try:
        with open(meminfo, encoding="ascii") as f:
            for line in f:
                name, _, rest = line.partition(":")
                fields = rest.split()
                if fields and fields[0].isdigit():
                    values[name] = int(fields[0])
    except OSError:
        return {}
    return values


def mem_percent(meminfo: str = "/proc/meminfo") -> int | None:
    values = _meminfo(meminfo)
    total = values.get("MemTotal", 0)
    available = values.get("MemAvailable")
    if available is None:
        return None
    return _percent(total - available, total)


def disk_percent(path: str | None = None) -> int | None:
    try:
        usage = shutil.disk_usage(path or os.environ.get("CORSIXTH_MP_DISK_PATH") or "/")
    except OSError:
        return None
    return _percent(usage.used, usage.total)


def mem_available_mb(meminfo: str = "/proc/meminfo") -> int | None:
    """Memory a new program can still have without swapping (MemAvailable), MB."""
    available = _meminfo(meminfo).get("MemAvailable")
    return None if available is None else available // 1024


def busy_cores() -> float | None:
    """How many cores are busy: the one-minute load average."""
    try:
        return os.getloadavg()[0]
    except (AttributeError, OSError):
        return None


_capacity: dict[str, float | int | None] = {}
_capacity_at = 0.0


def capacity() -> dict[str, float | int | None]:
    """{"cores": n, "busy": cores busy (one-minute load), "free_mb": MB
    available}, read at most every CACHE_SECONDS; None where it cannot be
    read."""
    global _capacity, _capacity_at
    now = time.monotonic()
    if not _capacity or now - _capacity_at >= CACHE_SECONDS:
        _capacity = {"cores": os.cpu_count() or 1, "busy": busy_cores(), "free_mb": mem_available_mb()}
        _capacity_at = now
    return dict(_capacity)


def load() -> dict[str, int | None]:
    """{"cpu": .., "mem": .., "disk": ..}, read at most every CACHE_SECONDS."""
    global _cached, _cached_at
    now = time.monotonic()
    if not _cached or now - _cached_at >= CACHE_SECONDS:
        _cached = {"cpu": cpu_percent(), "mem": mem_percent(), "disk": disk_percent()}
        _cached_at = now
    return dict(_cached)
