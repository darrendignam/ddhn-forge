#!/usr/bin/env python3
"""Validate http/user-data before a Packer build spends a VM boot discovering it is wrong.

subiquity rejects a malformed autoinstall with a single line on the VM console and no
network, so the failure surfaces only as Packer waiting out its 45 minute SSH timeout.
This catches the classes of mistake that have actually happened here.
"""
import sys
import pathlib
import yaml

USER_DATA = pathlib.Path(__file__).resolve().parents[2] / "http" / "user-data"

REQUIRED = ["version", "identity", "storage"]


def fail(message):
    print(f"FAIL  {message}")
    return 1


def main():
    if not USER_DATA.is_file():
        return fail(f"{USER_DATA} does not exist")

    try:
        document = yaml.safe_load(USER_DATA.read_text())
    except yaml.YAMLError as error:
        return fail(f"user-data is not valid YAML: {error}")

    if "autoinstall" not in document:
        return fail("no top level 'autoinstall' key")

    autoinstall = document["autoinstall"]
    errors = 0

    for key in REQUIRED:
        if key not in autoinstall:
            errors += fail(f"missing required section '{key}'")

    # The one that bit us: an unquoted scalar containing ": " parses as a mapping, and
    # subiquity reports only "Malformed autoinstall in 'late-commands' section".
    for section in ("late-commands", "early-commands"):
        for index, command in enumerate(autoinstall.get(section, [])):
            if isinstance(command, str):
                continue
            if isinstance(command, list) and all(isinstance(p, str) for p in command):
                continue
            errors += fail(
                f"{section}[{index}] parsed as {type(command).__name__}, not a string "
                f"or list of strings. Quote the whole entry: a ': ' inside an unquoted "
                f"YAML scalar becomes a mapping.\n      got: {command!r}"
            )

    identity = autoinstall.get("identity", {})
    for key in ("username", "password", "hostname"):
        if not identity.get(key):
            errors += fail(f"identity.{key} is empty or missing")

    if errors:
        print(f"\n{errors} problem(s) found in {USER_DATA}")
        return 1

    print(f"OK    {USER_DATA} is a valid autoinstall document")
    print(f"      late-commands: {len(autoinstall.get('late-commands', []))} entries, all strings")
    return 0


if __name__ == "__main__":
    sys.exit(main())
