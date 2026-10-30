"""Offline checks for the NetBird API reconciler's write behavior."""

import copy
import importlib.util
from pathlib import Path
import unittest
from unittest import mock


SCRIPT = Path(__file__).with_name("netbird-uni-next-sync.py")
spec = importlib.util.spec_from_file_location("netbird_uni_next_sync", SCRIPT)
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)


class FakeAPI:
    def __init__(self):
        self.objects = {
            "/accounts": [{"settings": {"network_range": "100.4.0.0/16"}}],
            "/groups": [{"id": "all", "name": "All", "peers_count": 1}],
            "/networks": [],
            "/policies": [],
        }
        self.writes = []
        self.next_id = 1

    def request(self, method, path, payload=None):
        if method == "GET" and path.startswith("/groups/"):
            return {"id": path.rsplit("/", 1)[1], "peers_count": 1}
        if method == "GET":
            return copy.deepcopy(self.objects.setdefault(path, []))
        self.writes.append((method, path))
        if method == "POST":
            obj = copy.deepcopy(payload)
            obj["id"] = f"id{self.next_id}"
            self.next_id += 1
            self.objects.setdefault(path, []).append(obj)
            return copy.deepcopy(obj)
        if method == "PUT":
            parent, ident = path.rsplit("/", 1)
            obj = copy.deepcopy(payload)
            obj["id"] = ident
            self.objects[parent] = [obj if x["id"] == ident else x for x in self.objects[parent]]
            return copy.deepcopy(obj)
        raise AssertionError((method, path))


CONFIG = {
    "api_url": "https://netbird.example.test",
    "source_cidr": "100.4.0.0/16",
    "network_name": "uni-next-kingscross",
    "resource_name": "uni-next-dev-machine",
    "resource_address": "10.19.20.1/32",
    "router_group": "uni-next-kingscross-router",
    "resource_group": "uni-next-kingscross-resources",
    "source_groups": ["All"],
    "policy_name": "uni-next-kingscross-access",
    "setup_key_name": "uni-next-kingscross-once",
    "description": "Managed by nixos-config: KingsCross UniVPN gateway",
}


class ReconcileTests(unittest.TestCase):
    def test_second_run_does_not_write_and_updates_drift(self):
        api = FakeAPI()
        with mock.patch.object(sync, "ensure_peer"):
            sync.reconcile(api, CONFIG, "/bin/false", Path("/run/test"))
            self.assertEqual(len(api.writes), 6)
            api.writes.clear()
            api.objects["/networks/id3/resources"][0]["address"] = "10.19.20.1"
            sync.reconcile(api, CONFIG, "/bin/false", Path("/run/test"))
            self.assertEqual(api.writes, [])
            changed = CONFIG | {"resource_address": "10.19.20.2/32"}
            sync.reconcile(api, changed, "/bin/false", Path("/run/test"))
            self.assertEqual(api.writes, [("PUT", "/networks/id3/resources/id4")])

    def test_duplicate_managed_name_fails_closed(self):
        api = FakeAPI()
        api.objects["/groups"].append({"id": "x", "name": CONFIG["router_group"]})
        api.objects["/groups"].append({"id": "y", "name": CONFIG["router_group"]})
        with self.assertRaises(sync.SyncError):
            sync.reconcile(api, CONFIG, "/bin/false", Path("/run/test"))
        self.assertEqual(api.writes, [])

    def test_account_range_change_fails_before_writes(self):
        api = FakeAPI()
        api.objects["/accounts"][0]["settings"]["network_range"] = "100.5.0.0/16"
        with self.assertRaises(sync.SyncError):
            sync.reconcile(api, CONFIG, "/bin/false", Path("/run/test"))
        self.assertEqual(api.writes, [])


if __name__ == "__main__":
    unittest.main()
