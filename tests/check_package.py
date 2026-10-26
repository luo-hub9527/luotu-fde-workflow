"""Check distributable files, local links and pinned upstream attribution.

This is a structural/package check, not a behavioral evaluation of the skill.
Run from the repository root: python tests/check_package.py
"""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SKILL = ROOT / "skills" / "fde-workflow"
EXPECTED = {
    "SKILL.md", "LICENSE", "NOTICE.md", "upstream-lock.json", "licenses/FDEOps-MIT.txt",
    "references/context.md", "references/discovery-demo.md",
    "references/feasibility.md", "references/commercial.md",
    "references/build-deliver.md", "references/operate-close.md",
    "assets/project-state.md", "assets/discovery-assessment.md",
    "assets/requirements-plan.md", "assets/internal-costing.md",
    "assets/customer-proposal.md", "assets/delivery-service.md",
}


def check() -> dict:
    paths = {p.relative_to(SKILL).as_posix(): p for p in SKILL.rglob("*") if p.is_file()}
    if set(paths) != EXPECTED:
        raise ValueError(f"Package inventory differs: missing={sorted(EXPECTED-set(paths))}, extra={sorted(set(paths)-EXPECTED)}")

    checked_links = 0
    for relative, path in paths.items():
        if path.suffix != ".md":
            continue
        content = path.read_text(encoding="utf-8-sig")
        for target in re.findall(r"\]\(([^)]+)\)", content):
            if re.match(r"(?:https?://|#)", target):
                continue
            linked = (path.parent / target.split("#", 1)[0]).resolve()
            if not linked.is_relative_to(SKILL.resolve()):
                raise ValueError(f"Link leaves standalone skill: {relative}")
            if not linked.is_file():
                raise ValueError(f"Missing local link in {relative}: {target}")
            checked_links += 1

    lock = json.loads(paths["upstream-lock.json"].read_text(encoding="utf-8-sig"))
    if not re.fullmatch(r"[a-f0-9]{40}", lock["commit"]):
        raise ValueError("Upstream must be pinned to a full commit.")
    if lock["repository"] != "https://github.com/suboss87/FDEOps":
        raise ValueError("Review the source mapping before changing upstream.")
    for entry in lock["files"]:
        if not re.fullmatch(r"[a-f0-9]{64}", entry["sha256"]):
            raise ValueError("Invalid upstream source hash.")
        expected_url = f'https://raw.githubusercontent.com/suboss87/FDEOps/{lock["commit"]}/{entry["path"]}'
        if entry["source_url"] != expected_url:
            raise ValueError("Upstream source URL is not commit-pinned.")

    license_entry = next(entry for entry in lock["files"] if entry["path"] == "LICENSE")
    license_hash = hashlib.sha256(paths["licenses/FDEOps-MIT.txt"].read_bytes()).hexdigest()
    if license_hash != license_entry["sha256"]:
        raise ValueError("Bundled upstream license bytes differ from the pinned original.")
    if lock["commit"] not in paths["NOTICE.md"].read_text(encoding="utf-8"):
        raise ValueError("NOTICE and upstream lock disagree.")

    return {
        "package_files": len(paths),
        "resolved_local_links": checked_links,
        "upstream_commit": lock["commit"],
        "license_sha256": license_hash,
        "scope": "Inventory, portable local links and pinned attribution only; not model behavior.",
    }


if __name__ == "__main__":
    print(json.dumps(check(), ensure_ascii=False, indent=2))
