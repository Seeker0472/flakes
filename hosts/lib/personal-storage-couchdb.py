#!/usr/bin/env python3
"""Idempotent CouchDB account/database bootstrap, waiting for API readiness."""

import base64
import json
from pathlib import Path
import sys
import time
import urllib.error
import urllib.request


def main():
    secrets = json.loads(Path(sys.argv[1]).read_text())
    base = f"http://127.0.0.1:{int(sys.argv[2])}"
    passwords = {"admin": secrets["couchdb_admin_password"], "livesync": secrets["livesync_password"]}

    def request(method, path, body=None, user="admin", accepted=(200, 201, 202)):
        auth = base64.b64encode(f"{user}:{passwords[user]}".encode()).decode()
        req = urllib.request.Request(base + path, method=method,
            data=None if body is None else json.dumps(body).encode(),
            headers={"Authorization": "Basic " + auth, "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(req, timeout=15) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            if error.code in accepted:
                return None
            raise

    for database in ("_users", "_replicator", "obsidian"):
        request("PUT", "/" + database, {}, accepted=(201, 202, 412))
    if request("GET", "/_session", user="livesync", accepted=(200, 401)) is None:
        path = "/_users/org.couchdb.user:livesync"
        previous = request("GET", path, accepted=(200, 404)) or {}
        user = {"name": "livesync", "type": "user", "roles": [], "password": passwords["livesync"]}
        if "_rev" in previous:
            user["_rev"] = previous["_rev"]
        request("PUT", path, user)
    request("PUT", "/obsidian/_security", {
        "admins": {"names": ["livesync"], "roles": []},
        "members": {"names": ["livesync"], "roles": []},
    })
    print("LiveSync database and restricted account ready")


if __name__ == "__main__":
    for attempt in range(60):
        try:
            main()
            break
        except (OSError, ValueError, urllib.error.URLError) as error:
            if attempt == 59:
                print(f"CouchDB bootstrap: {error}", file=sys.stderr)
                sys.exit(1)
            time.sleep(1)
