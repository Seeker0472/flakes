#!/usr/bin/env python3
"""Enforce the shared ext4 quota and protect CouchDB compaction headroom."""

import argparse
from contextlib import contextmanager
import csv
import io
import fcntl
import json
import os
from pathlib import Path
import pwd
import stat
import subprocess
import sys
import time


class StorageError(Exception):
    pass


def quota(mount, identity, kind, limits=None):
    flag = "-P" if kind == 2 else "-u"
    if limits is not None:
        hard, inodes = limits
        subprocess.run(["setquota", flag, str(identity), "0", str(hard), "0", str(inodes), mount], check=True)
        return
    report = subprocess.run(["repquota", flag, "-n", "-O", "csv", mount], check=True, capture_output=True, text=True).stdout
    rows = csv.DictReader(io.StringIO(report))
    key = "Project" if kind == 2 else "User"
    row = next((r for r in rows if r[key] == f"#{identity}"), {})
    return {
        "block_hard": int(row.get("BlockHardLimit", 0)),
        "space": int(row.get("BlockUsed", 0)) * 1024,
        "inode_hard": int(row.get("FileHardLimit", 0)),
        "inodes": int(row.get("FileUsed", 0)),
    }


def filesystem(cfg):
    result = subprocess.run(
        ["findmnt", "--json", "--target", cfg["base"] if Path(cfg["base"]).exists() else cfg["mount"], "--output", "SOURCE,FSTYPE,TARGET,OPTIONS"],
        check=True, capture_output=True, text=True,
    )
    fs = json.loads(result.stdout)["filesystems"][0]
    if fs["fstype"] != "ext4" or fs["target"] != cfg["mount"]:
        raise StorageError("personal storage must be on the configured ext4 mount")
    return fs


def write_json(path, value):
    path = Path(path)
    temporary = path.with_suffix(".new")
    temporary.write_text(json.dumps(value) + "\n")
    temporary.replace(path)


def preflight(cfg):
    fs = filesystem(cfg)
    for option in ("usrquota", "prjquota"):
        if option not in fs["options"].split(","):
            raise StorageError(f"{option} is not enforced; complete the offline ext4 preparation first")
    device = cfg["mount"]
    current = quota(device, cfg["project_id"], 2)
    hard = cfg["quota_bytes"] // 1024
    if current["space"] > hard * 1024 or current["inodes"] > cfg["inode_limit"]:
        raise StorageError("refusing to shrink quota below current usage; no data has been deleted")
    # ext4 statfs on a +P directory reports that project's remaining quota.
    # Check the mount root instead, otherwise every online increase is refused.
    available = os.statvfs(cfg["mount"])
    if hard > current["block_hard"] and hard * 1024 > current["space"] + available.f_bavail * available.f_frsize:
        raise StorageError("the requested quota exceeds currently available filesystem capacity")
    return device, hard


@contextmanager
def quota_lock(cfg):
    with open(Path(cfg["runtime"]) / "quota-update.lock", "a") as stream:
        fcntl.flock(stream, fcntl.LOCK_EX)
        yield


def initialize(cfg):
    preflight(cfg)
    with quota_lock(cfg):
        initialize_locked(cfg)


def initialize_locked(cfg):
    device, hard = preflight(cfg)
    base = Path(cfg["base"])
    base.mkdir(mode=0o711, parents=True, exist_ok=True)
    quota(device, cfg["project_id"], 2, (hard, cfg["inode_limit"]))
    # +P prevents moving/linking differently tagged inodes into this tree.
    # Only recurse on first adoption. Subsequent writes inherit the ID.
    attributes = subprocess.run(
        ["lsattr", "-p", "-d", str(base)], capture_output=True, text=True, check=True,
    ).stdout.split()
    if int(attributes[0]) != cfg["project_id"] or "P" not in attributes[1]:
        subprocess.run(["chattr", "-R", "-p", str(cfg["project_id"]), str(base)], check=True)
        # +P applies to directories only. Mark the root last so an interrupted
        # adoption is retried rather than mistaken for a completed adoption.
        for folder, _, _ in os.walk(base, topdown=False, followlinks=False):
            subprocess.run(["chattr", "+P", folder], check=True)
    directories = {
        "couchdb": ("couchdb", 0o700),
        "transfer": ("copyparty", 0o750),
        "copyparty": ("copyparty", 0o700),
        "copyparty/history": ("copyparty", 0o700),
        "nginx": ("nginx", 0o700),
        "journal": ("root", 0o755),
        "sftp": ("root", 0o700),
        "sftp/root": ("root", 0o755),
        "sftp/root/files": ("root", 0o755),
    }
    for name, (owner, mode) in directories.items():
        directory = base / name
        subprocess.run(["install", "-d", "-m", f"{mode:o}", "-o", owner, "-g", owner, str(directory)], check=True)
        subprocess.run(["chattr", "-p", str(cfg["project_id"]), "+P", str(directory)], check=True)
    os.chmod(base, 0o711)
    write_json(Path(cfg["runtime"]) / "config.json", cfg)
    update_budget(cfg, device)
    print("personal storage: shared quota and project inheritance verified")


def couchdb_size(base):
    # Count every live database shard and view index; exclude compaction copies
    # which already consume the shared quota. Never follow symlinks.
    total = 0
    for root, dirs, files in os.walk(Path(base) / "couchdb", followlinks=False):
        dirs[:] = [d for d in dirs if not (Path(root) / d).is_symlink()]
        for name in files:
            if ".compact" in name or not name.endswith((".couch", ".view")):
                continue
            try:
                item = (Path(root) / name).lstat()
                if stat.S_ISREG(item.st_mode):
                    total += item.st_size
            except FileNotFoundError:
                pass
    return total


def budget_limit(shared, transfer, reserve, cleanup_bytes):
    additional = max(0, shared["block_hard"] * 1024 - shared["space"] - reserve)
    desired = (transfer["space"] + additional) // 1024
    if additional < cleanup_bytes:
        # Allow bounded SQLite/cleanup work, but do not ratchet the allowance
        # upward on every poll while an existing upload is still writing.
        cleanup_ceiling = (transfer["space"] + cleanup_bytes) // 1024
        desired = min(transfer["block_hard"] or cleanup_ceiling, cleanup_ceiling)
    return max(1, desired), additional


def update_budget(cfg, device):
    shared = quota(device, cfg["project_id"], 2)
    if shared["block_hard"] != cfg["quota_bytes"] // 1024:
        raise StorageError("shared hard quota differs from the declarative configuration")
    uid = pwd.getpwnam("copyparty").pw_uid
    transfer = quota(device, uid, 0)
    databases = couchdb_size(cfg["base"])
    reserve = max(cfg["minimum_reserve_bytes"], databases + cfg["compaction_margin_bytes"])
    hard, additional = budget_limit(shared, transfer, reserve, cfg["cleanup_allowance_bytes"])
    if transfer["block_hard"] != hard or transfer["inode_hard"] != cfg["inode_limit"]:
        quota(device, uid, 0, (hard, cfg["inode_limit"]))
    write_json(Path(cfg["runtime"]) / "status.json", {
        "updated_at": time.time(), "quota_bytes": shared["block_hard"] * 1024,
        "used_bytes": shared["space"], "used_inodes": shared["inodes"],
        "couchdb_bytes": databases, "compaction_reserve_bytes": reserve,
        "transfer_headroom_bytes": additional,
        "transfer_user_limit_bytes": hard * 1024,
    })


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("command", choices=("preflight", "initialize", "monitor", "status"))
    args = parser.parse_args()
    cfg = json.loads(args.config.read_text())
    if args.command == "preflight":
        preflight(cfg)
    elif args.command == "initialize":
        initialize(cfg)
    elif args.command == "status":
        print((Path(cfg["runtime"]) / "status.json").read_text(), end="")
    else:
        while True:
            with quota_lock(cfg):
                current = json.loads((Path(cfg["runtime"]) / "config.json").read_text())
                filesystem(current)
                update_budget(current, current["mount"])
            time.sleep(1)


if __name__ == "__main__":
    try:
        main()
    except (StorageError, OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"personal-storage: {error}", file=sys.stderr)
        sys.exit(1)
