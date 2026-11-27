import os
import pathlib
import subprocess
import sys

SERVER = pathlib.Path(__file__).resolve().parent.parent


def _settings_seen(extra):
    """The CORSIXTH_MP_ settings the server code sees, run with these
    environment variables (a fresh Python: the names are copied on import)."""
    env = {k: v for k, v in os.environ.items() if not k.startswith(("OPENTH_", "CORSIXTH_MP_"))}
    env.update(extra)
    out = subprocess.run(
        [sys.executable, "-c",
         "import os, corsixth_mp; print(sorted((k, v) for k, v in os.environ.items()"
         " if k.startswith('CORSIXTH_MP_')))"],
        cwd=SERVER, env=env, capture_output=True, text=True, check=True).stdout
    return dict(eval(out))  # noqa: S307 (our own print of a list of pairs)


def test_openth_settings_reach_the_code():
    seen = _settings_seen({"OPENTH_MOTD": "hello", "OPENTH_EXPERTS": "Argus"})
    assert seen == {"CORSIXTH_MP_MOTD": "hello", "CORSIXTH_MP_EXPERTS": "Argus"}


def test_first_names_still_work_and_the_new_one_wins():
    seen = _settings_seen({"CORSIXTH_MP_MOTD": "old", "CORSIXTH_MP_LOG": "DEBUG", "OPENTH_MOTD": "new"})
    assert seen == {"CORSIXTH_MP_MOTD": "new", "CORSIXTH_MP_LOG": "DEBUG"}
