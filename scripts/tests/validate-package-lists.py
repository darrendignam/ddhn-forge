#!/usr/bin/env python3
"""Check that the apt removal lists cannot take anything else with them.

apt removes reverse dependencies alongside whatever it is asked to remove. Three
entries in the VM removal list, inherited from the Debian 12 build, would have taken
out openjdk-21-jre, ca-certificates, caja and mate-desktop-environment-core, which is
to say the Java runtime, HTTPS and the desktop. Nothing caught it because the removal
runs about forty minutes into a VM build that had never got that far.

Run against a built container or VM:

    validate-package-lists.py                 # uses the docker-viper container
    validate-package-lists.py --host          # runs against this machine
"""
import argparse
import pathlib
import re
import subprocess
import sys

import yaml

DEFAULTS = (
    pathlib.Path(__file__).resolve().parents[2]
    / "ansible" / "roles" / "viper.setup" / "defaults" / "main.yml"
)


def run(command, container):
    if container:
        command = ["docker", "exec", container, "bash", "-lc", command]
    else:
        command = ["bash", "-lc", command]
    return subprocess.run(command, capture_output=True, text=True).stdout


def installed(package, container):
    return bool(run(f"dpkg-query -W {package} 2>/dev/null", container).strip())


def collateral(package, container):
    """Packages apt would remove in addition to the one named."""
    output = run(f"apt-get -s remove {package} 2>/dev/null", container)
    removed = re.findall(r"^Remv (\S+)", output, re.MULTILINE)
    return [name for name in removed if name != package]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", action="store_true", help="check this machine, not a container")
    parser.add_argument("--container", default="docker-viper")
    parser.add_argument("--list", default="viper_env_apt_vm_remove")
    args = parser.parse_args()

    container = None if args.host else args.container
    defaults = yaml.safe_load(DEFAULTS.read_text())

    remove_list = set(defaults[args.list])
    keep_list = set(defaults["viper_env_apt_vm_defaults"]) | set(
        defaults["viper_env_apt_docker_defaults"]
    )

    problems = 0
    checked = 0

    for package in sorted(remove_list):
        if not installed(package, container):
            continue
        checked += 1
        extra = [name for name in collateral(package, container) if name not in remove_list]
        if not extra:
            continue
        problems += 1
        print(f"FAIL  removing '{package}' would also remove:")
        for name in extra:
            flag = "  <-- also in an install list" if name in keep_list else ""
            print(f"        {name}{flag}")

    print()
    if problems:
        print(f"{problems} of {checked} installed entries in {args.list} remove more than themselves")
        return 1
    print(f"OK    all {checked} installed entries in {args.list} remove only themselves")
    return 0


if __name__ == "__main__":
    sys.exit(main())
