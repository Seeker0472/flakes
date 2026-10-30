#!/usr/bin/env python3
"""Reconcile the KingsCross UniVPN route with NetBird's management API.

Only objects with the configured names are managed. Unrelated API objects are
never deleted. The API token and one-off setup key stay outside the Nix store.
"""

import argparse
import ipaddress
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import urllib.error
import urllib.request


class SyncError(Exception):
    pass


class API:
    def __init__(self, base_url, token):
        if not base_url.startswith("https://"):
            raise SyncError("NetBird API URL must use HTTPS")
        self.base = base_url.rstrip("/") + "/api"
        self.token = token
        self.opener = urllib.request.build_opener(NoRedirect())

    def request(self, method, path, payload=None):
        data = None if payload is None else json.dumps(payload).encode()
        request = urllib.request.Request(
            self.base + path,
            data=data,
            method=method,
            headers={
                "Accept": "application/json",
                "Content-Type": "application/json",
                "Authorization": "Token " + self.token,
            },
        )
        try:
            with self.opener.open(request, timeout=15) as response:
                body = response.read(2_000_000)
        except urllib.error.HTTPError as error:
            # API error bodies can include request data. Do not log them.
            raise SyncError(f"NetBird API {method} {path}: HTTP {error.code}") from None
        except urllib.error.URLError as error:
            raise SyncError(f"NetBird API {method} {path}: connection failed") from None
        if not body:
            return None
        try:
            return json.loads(body)
        except json.JSONDecodeError:
            raise SyncError(f"NetBird API {method} {path}: invalid JSON") from None


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, newurl):
        # Never forward a PAT to a different URL or host.
        return None


def named(items, name, kind):
    matches = [item for item in items if item.get("name") == name]
    if len(matches) > 1:
        raise SyncError(f"multiple {kind} objects named {name!r}")
    return matches[0] if matches else None


def collection(api, path):
    # NetBird 0.81 returns JSON null for an empty Network Resources list.
    items = api.request("GET", path)
    if items is None:
        return []
    if not isinstance(items, list):
        raise SyncError(f"NetBird API GET {path}: expected a list")
    return items


def upsert_named(api, path, name, desired, kind):
    current = named(collection(api, path), name, kind)
    if current is None:
        print(f"creating {kind} {name}")
        return api.request("POST", path, desired)
    if kind == "group":
        return current
    if kind == "network":
        same = current.get("description") == desired["description"]
    elif kind == "resource":
        groups = [g.get("id", g) if isinstance(g, dict) else g for g in current.get("groups", [])]
        try:
            address_matches = ipaddress.ip_network(current.get("address"), strict=False) == ipaddress.ip_network(desired["address"], strict=False)
        except (ValueError, TypeError):
            address_matches = False
        same = (
            address_matches
            and all(current.get(k) == desired[k] for k in ("description", "enabled"))
            and sorted(groups) == sorted(desired["groups"])
        )
    elif kind == "policy":
        rules = current.get("rules") or []
        rule = rules[0] if len(rules) == 1 else {}
        want = desired["rules"][0]
        sources = [g.get("id", g) if isinstance(g, dict) else g for g in rule.get("sources", [])]
        dest = rule.get("destinationResource") or {}
        same = (
            current.get("description") == desired["description"]
            and current.get("enabled") == desired["enabled"]
            and len(rules) == 1
            and sorted(sources) == sorted(want["sources"])
            and dest.get("id") == want["destinationResource"]["id"]
            and dest.get("type") == want["destinationResource"]["type"]
            and all(rule.get(k) == want[k] for k in ("name", "enabled", "action", "bidirectional", "protocol"))
        )
    else:
        raise SyncError(f"unknown managed kind {kind}")
    if not same:
        print(f"updating {kind} {name}")
        return api.request("PUT", f"{path}/{current['id']}", desired)
    return current


def ensure_router(api, network_id, group_id):
    path = f"/networks/{network_id}/routers"
    routers = collection(api, path)
    matches = [r for r in routers if r.get("peer_groups") == [group_id] and not r.get("peer")]
    if len(matches) > 1:
        raise SyncError("multiple UniVPN routing peers found")
    desired = {"peer_groups": [group_id], "metric": 100, "masquerade": True, "enabled": True}
    if not matches:
        print("creating UniVPN routing peer")
        api.request("POST", path, desired)
    elif any(matches[0].get(k) != v for k, v in desired.items()):
        print("updating UniVPN routing peer")
        api.request("PUT", f"{path}/{matches[0]['id']}", desired)


def netbird_status(binary):
    result = subprocess.run([binary, "status"], capture_output=True, text=True, timeout=20, check=False)
    return result.stdout + result.stderr


def ensure_peer(api, cfg, binary, runtime_dir, router_group_id):
    for _ in range(30):
        status = netbird_status(binary)
        if "NeedsLogin" in status:
            break
        if "Management: Connected" in status:
            print("NetBird routing peer already enrolled")
            return
        time.sleep(1)
    else:
        raise SyncError("NetBird client did not become ready for enrollment")

    key = api.request("POST", "/setup-keys", {
        "name": cfg["setup_key_name"],
        "type": "one-off",
        "expires_in": 86400,
        "auto_groups": [router_group_id],
        "usage_limit": 1,
        "ephemeral": False,
    })["key"]
    key_file = runtime_dir / "setup-key"
    fd = os.open(key_file, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(key + "\n")
        environment = os.environ.copy()
        environment["NB_SETUP_KEY_FILE"] = str(key_file)
        print("enrolling NetBird routing peer")
        subprocess.run(
            [binary, "up", "--management-url", cfg["api_url"]],
            env=environment,
            timeout=90,
            check=True,
        )
    finally:
        key_file.unlink(missing_ok=True)


def wait_for_router_group(api, group_id):
    for _ in range(30):
        group = api.request("GET", f"/groups/{group_id}")
        count = group.get("peers_count", len(group.get("peers") or []))
        if count == 1:
            return
        if count > 1:
            raise SyncError("UniVPN routing group contains more than one peer")
        time.sleep(1)
    raise SyncError("NetBird routing peer did not join its group")


def reconcile(api, cfg, binary, runtime_dir):
    accounts = collection(api, "/accounts")
    if len(accounts) != 1 or accounts[0].get("settings", {}).get("network_range") != cfg["source_cidr"]:
        raise SyncError("NetBird account address range differs from the Nix source CIDR")
    router_group = upsert_named(api, "/groups", cfg["router_group"], {"name": cfg["router_group"]}, "group")
    resource_group = upsert_named(api, "/groups", cfg["resource_group"], {"name": cfg["resource_group"]}, "group")
    groups = collection(api, "/groups")
    source_ids = []
    for name in cfg["source_groups"]:
        group = named(groups, name, "source group")
        if group is None:
            raise SyncError(f"source group {name!r} does not exist")
        source_ids.append(group["id"])

    network = upsert_named(api, "/networks", cfg["network_name"], {
        "name": cfg["network_name"],
        "description": cfg["description"],
    }, "network")
    resource = upsert_named(api, f"/networks/{network['id']}/resources", cfg["resource_name"], {
        "name": cfg["resource_name"],
        "description": cfg["description"],
        "address": cfg["resource_address"],
        "enabled": True,
        "groups": [resource_group["id"]],
    }, "resource")
    ensure_peer(api, cfg, binary, runtime_dir, router_group["id"])
    wait_for_router_group(api, router_group["id"])
    ensure_router(api, network["id"], router_group["id"])
    upsert_named(api, "/policies", cfg["policy_name"], {
        "name": cfg["policy_name"],
        "description": cfg["description"],
        "enabled": True,
        "rules": [{
            "name": cfg["policy_name"],
            "enabled": True,
            "action": "accept",
            "bidirectional": False,
            "protocol": "all",
            "sources": source_ids,
            "destinationResource": {"id": resource["id"], "type": "host"},
        }],
    }, "policy")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--token-file", type=Path, required=True)
    parser.add_argument("--netbird-bin", required=True)
    parser.add_argument("--runtime-dir", type=Path, required=True)
    args = parser.parse_args()
    cfg = json.loads(args.config.read_text())
    token = args.token_file.read_text().strip()
    if not token:
        raise SyncError("NetBird API token is empty")
    reconcile(API(cfg["api_url"], token), cfg, args.netbird_bin, args.runtime_dir)


if __name__ == "__main__":
    try:
        main()
    except (SyncError, KeyError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        print(f"netbird-uni-next-sync: {error}", file=sys.stderr)
        sys.exit(1)
