"""OpenTH multiplayer relay and lobby server (CorsixTH with network multiplayer)."""

import os as _os
import pathlib as _pathlib


def service_dir() -> _pathlib.Path | None:
    """The service account's folder on a server set up by setup-referee-host.sh:
    /var/lib/openth (/var/lib/corsixth on servers set up before 2026-11-27),
    or None elsewhere."""
    for folder in ("/var/lib/openth", "/var/lib/corsixth"):
        if _pathlib.Path(folder).is_dir():
            return _pathlib.Path(folder)
    return None


# Settings are named OPENTH_<NAME> (/etc/openth.env on a server, since
# 2026-11-27). The code, the referee and the bots read them under their first
# names, CORSIXTH_MP_<NAME>, which still work too: copy each OPENTH_ setting
# over (the new name wins). Child processes (referee, bots) inherit the copies.
for _name, _value in list(_os.environ.items()):
    if _name.startswith("OPENTH_") and len(_name) > 7:
        _os.environ["CORSIXTH_MP_" + _name[7:]] = _value
