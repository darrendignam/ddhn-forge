#!/usr/bin/env python3
"""Check that the documentation's version data matches what the appliance ships.

docs/_data/vars.yml is rendered into the published tools page. Nothing in the build
reads it, so it drifts silently: it went on advertising Debian 12, DROID 6.7.0 and
JHOVE 1.30.1 for releases that shipped none of them, and no test would ever have
noticed. This is the only check here that protects what users read rather than what
they run.

Three sources of truth, in order of authority:

  the tool defaults    for tools ViPER installs itself, from an upstream URL
  a built image        for applications that come from Ubuntu's archive, whose
                       versions ViPER does not choose and cannot predict
  the pages themselves for whether every variable they reference exists at all

Usage:

    validate-doc-versions.py                      # against the docker-viper container
    validate-doc-versions.py --container NAME     # against another container
    validate-doc-versions.py --no-image           # skip the apt package checks
"""
import argparse
import glob
import pathlib
import re
import subprocess
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[2]
DOC_VARS = ROOT / "docs" / "_data" / "vars.yml"
TOOL_DEFAULTS = ROOT / "ansible" / "roles" / "viper.tools" / "defaults" / "main.yml"

# Documentation variable -> key in the tool defaults. These are the tools ViPER pins
# and installs from an upstream release, so the defaults are authoritative.
PINNED_TOOLS = {
    "droid_version": "droid_version",
    "jhove_version": "jhove_version",
    "verapdf_version": "verapdf_version",
    "verapdf_arlington_version": "verapdf_arlington_version",
    "tika_version": "tika_version",
    "fido_version": "fido_version",
    "jpylyzer_version": "jpylyzer_version",
    "odf_validator_version": "odf_validator_version",
    "openfixity_version": "openfixity_version",
    "rclone_version": "rclone_version",
}

# Documentation variable -> Debian package name. ViPER does not choose these versions,
# so a built image is the only place the truth exists.
APT_APPLICATIONS = {
    "handbrake_version": "handbrake",
    "inkscape_version": "inkscape",
    "gimp_version": "gimp",
}

# MediaArea publishes its own packages, pinned by filename in the tool defaults.
MEDIAAREA = {
    "mediainfo_version": "mediainfo",
    "mediaconch_version": "mediaconch",
}


def fail(message):
    print(f"FAIL  {message}")
    return 1


def render(value, variables, depth=0):
    """Resolve the simple {{ name }} references the tool defaults use for versions."""
    if not isinstance(value, str) or depth > 5:
        return value
    if "{{" not in value:
        return value
    resolved = re.sub(
        r"\{\{\s*(\w+)\s*\}\}",
        lambda m: str(variables.get(m.group(1), m.group(0))),
        value,
    )
    return render(resolved, variables, depth + 1)


def container_command(command, container):
    argv = ["docker", "exec", container, "bash", "-lc", command]
    result = subprocess.run(argv, capture_output=True, text=True)
    return result.stdout.strip()


def apt_version(package, container):
    """Upstream version only: strip epoch, Debian revision and any build suffix.

    The format string is single quoted so the shell does not expand ${Version} to
    nothing before dpkg-query sees it, which makes dpkg reject an empty format and
    every package look absent.
    """
    raw = container_command(
        f"dpkg-query -W -f='${{Version}}' {package} 2>/dev/null", container
    )
    if not raw:
        return None
    return re.sub(r"[-+~].*$", "", re.sub(r"^\d+:", "", raw))


def mediaarea_versions(defaults):
    """Pull the pinned MediaArea versions out of their package filenames."""
    found = {}
    for entry in defaults["viper"]["tools"].get("mediaarea", []):
        match = re.match(r"^([a-z0-9-]+?)_([0-9.]+)-", entry["package_name"])
        if match:
            found[match.group(1)] = match.group(2)
    return found


def check_referenced_variables(doc_vars):
    """Every site.data.vars.X a page uses must exist, or it renders as nothing."""
    used = set()
    for pattern in ("docs/**/*.md", "docs/**/*.html"):
        for path in glob.glob(str(ROOT / pattern), recursive=True):
            text = pathlib.Path(path).read_text(encoding="utf-8", errors="ignore")
            used |= set(re.findall(r"site\.data\.vars\.(\w+)", text))
    missing = sorted(used - set(doc_vars))
    if missing:
        return fail(f"pages reference variables that vars.yml does not define: {missing}")
    print(f"OK    all {len(used)} variables referenced by pages are defined")
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--container", default="docker-viper")
    parser.add_argument(
        "--no-image",
        action="store_true",
        help="skip the checks that need a built image",
    )
    args = parser.parse_args()

    doc_vars = yaml.safe_load(DOC_VARS.read_text())
    defaults = yaml.safe_load(TOOL_DEFAULTS.read_text())
    problems = 0

    for doc_key, default_key in sorted(PINNED_TOOLS.items()):
        if doc_key not in doc_vars:
            problems += fail(f"{doc_key} is missing from vars.yml")
            continue
        expected = render(defaults.get(default_key), defaults)
        actual = str(doc_vars[doc_key])
        if actual != str(expected):
            problems += fail(
                f"{doc_key}: docs say {actual}, the build pins {expected}"
            )
    if not problems:
        print(f"OK    all {len(PINNED_TOOLS)} pinned tool versions match the build")

    pinned_mediaarea = mediaarea_versions(defaults)
    for doc_key, package in sorted(MEDIAAREA.items()):
        expected = pinned_mediaarea.get(package)
        if expected and str(doc_vars.get(doc_key)) != expected:
            problems += fail(
                f"{doc_key}: docs say {doc_vars.get(doc_key)}, "
                f"the build pins {expected}"
            )

    if args.no_image:
        print("SKIP  apt application versions, no image consulted")
    else:
        probe = container_command("echo ok", args.container)
        if probe != "ok":
            print(
                f"SKIP  apt application versions, container '{args.container}' "
                f"is not running. Use --no-image to silence this."
            )
        else:
            for doc_key, package in sorted(APT_APPLICATIONS.items()):
                installed = apt_version(package, args.container)
                if installed is None:
                    problems += fail(f"{package} is not installed in the image")
                    continue
                if str(doc_vars.get(doc_key)) != installed:
                    problems += fail(
                        f"{doc_key}: docs say {doc_vars.get(doc_key)}, "
                        f"the image has {installed}"
                    )

            os_name = container_command(
                ". /etc/os-release && echo $NAME", args.container
            )
            os_version = container_command(
                ". /etc/os-release && echo $VERSION_ID", args.container
            )
            if doc_vars.get("guest_os") != os_name:
                problems += fail(
                    f"guest_os: docs say {doc_vars.get('guest_os')}, "
                    f"the image is {os_name}"
                )
            if str(doc_vars.get("guest_os_version")) != os_version:
                problems += fail(
                    f"guest_os_version: docs say {doc_vars.get('guest_os_version')}, "
                    f"the image is {os_version}"
                )
            if not problems:
                print("OK    apt applications and the base OS match the image")

    problems += check_referenced_variables(doc_vars)

    print()
    if problems:
        print(f"{problems} problem(s). docs/_data/vars.yml does not describe this build.")
        return 1
    print("docs/_data/vars.yml describes this build.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
