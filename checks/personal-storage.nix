{ pkgs }:
let
  sftpPython = pkgs.python3.withPackages (p: [ p.paramiko ]);
  certificate =
    pkgs.runCommand "personal-storage-test-certificate" { nativeBuildInputs = [ pkgs.openssl ]; }
      ''
        mkdir -p $out
        openssl req -x509 -newkey rsa:2048 -nodes -days 2 \
          -subj /CN=files.test -keyout $out/key.pem -out $out/cert.pem
      '';
in
pkgs.testers.runNixOSTest {
  name = "personal-storage";
  requiredFeatures.kvm = false;
  nodes.server = { config, lib, ... }: {
    imports = [ ../hosts/lib/personal-storage.nix ];
    virtualisation.emptyDiskImages = [ 256 ];
    virtualisation.memorySize = 2048;
    virtualisation.fileSystems."/srv" = {
      device = "/dev/vdb";
      fsType = "ext4";
      noCheck = true;
      options = [
        "usrquota"
        "prjquota"
      ];
    };
    systemd.services.format-test-storage = {
      unitConfig.DefaultDependencies = false;
      requiredBy = [ "srv.mount" ];
      before = [ "srv.mount" ];
      requires = [ "dev-vdb.device" ];
      after = [ "dev-vdb.device" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.e2fsprogs}/bin/mkfs.ext4 -F -O quota,project -E quotatype=usrquota:prjquota /dev/vdb";
      };
    };
    networking.interfaces.eth1.ipv4.addresses = [
      {
        address = "192.168.1.1";
        prefixLength = 24;
      }
    ];
    services.openssh.enable = true;
    services.personalStorage = {
      enable = true;
      quotaMountPoint = "/srv";
      quotaBytes = 64 * 1024 * 1024;
      minimumReserveBytes = 16 * 1024 * 1024;
      compactionMarginBytes = 4 * 1024 * 1024;
      cleanupAllowanceBytes = 1024 * 1024;
      retentionSeconds = 6;
      netbirdAddress = "192.168.1.1";
      netbirdCIDR = "192.168.1.0/24";
      netbirdInterface = "eth1";
      netbirdUnit = "network-online.target";
      credentialsFile = "/etc/personal-test-credentials.json";
      copypartyConfigFile = "/etc/personal-test-copyparty.conf";
      couchdbAdminFile = "/etc/personal-test-couchdb.ini";
      sftpAuthorizedKeysFile = "/run/transfer-test-key.pub";
      filesDomain = "files.test";
      internalFilesDomain = "files-internal.test";
      obsidianDomain = "obsidian.test";
    };
    environment.etc."personal-test-credentials.json".text = builtins.toJSON {
      transfer_password = "transfer-test";
      manager_password = "manager-test";
      couchdb_admin_password = "couchdb-test";
      livesync_password = "livesync-test";
    };
    environment.etc."personal-test-copyparty.conf".text = ''
      [accounts]
        transfer: transfer-test
        manager: manager-test
    '';
    environment.etc."personal-test-couchdb.ini".text = "[admins]\nadmin = couchdb-test\n";
    services.nginx.virtualHosts =
      lib.genAttrs [ "files.test" "files-internal.test" "obsidian.test" ]
        (_: {
          useACMEHost = lib.mkForce null;
          sslCertificate = "${certificate}/cert.pem";
          sslCertificateKey = "${certificate}/key.pem";
        });
    environment.systemPackages = [
      pkgs.curl
      pkgs.openssh
      pkgs.quota
      pkgs.e2fsprogs
      pkgs.python3
    ];
  };
  testScript = ''
    import shlex
    import time

    def ready(unit):
        try:
            server.wait_for_unit(unit, timeout=90)
        except Exception:
            print(server.succeed("personal-storage-logs -n 100 --no-pager"))
            print(server.succeed("systemctl status copyparty couchdb personal-storage-couchdb-init --no-pager || true"))
            raise

    server.start()
    ready("personal-storage-quota.service")
    ready("copyparty.service")
    ready("personal-storage-sftp.service")
    ready("personal-storage-couchdb-init.service")
    ready("nginx.service")
    assert "cap_sys_resource" not in server.succeed("systemctl show nginx -p CapabilityBoundingSet -p AmbientCapabilities")
    server.wait_for_open_port(3923, timeout=60)
    server.wait_until_succeeds("personal-storage-logs -u copyparty --no-pager | grep 'workers OK'")
    server.wait_for_open_port(28443)
    server.succeed("systemctl stop personal-storage-expire.timer")

    def web(path="/", account="transfer:transfer-test", internal=False, host="files.test", extra=""):
        ip = "192.168.1.1" if internal else "127.0.0.1"
        auth = "-u " + shlex.quote(account) if account else ""
        return f"curl -sk --noproxy '*' --resolve {host}:28443:{ip} {auth} {extra} https://{host}:28443{path}"

    with subtest("all file access requires credentials; public users cannot delete or overwrite"):
        server.succeed("echo transfer-fixture > /run/example.txt")
        server.succeed(web(extra="--fail-with-body -D - -F f=@/run/example.txt"))
        assert server.succeed(web("/example.txt", extra="--fail")).strip() == "transfer-fixture"
        assert server.succeed(web("/example.txt", account="", extra="-o /dev/null -w '%{http_code}'")).strip() in ("401", "403", "404")
        assert server.succeed(web("/example.txt?delete", extra="-X POST -o /dev/null -w '%{http_code}'")).strip() in ("403", "404", "405")
        server.succeed("echo replacement > /run/replacement.txt")
        server.succeed(web("/example.txt", extra="-T /run/replacement.txt -o /dev/null"))
        assert server.succeed(web("/example.txt?apnd", extra="-T /run/replacement.txt -o /dev/null -w '%{http_code}'")).strip() == "400"
        assert server.succeed(web("/example.txt", extra="--fail")).strip() == "transfer-fixture"
        # Even a valid manager password plus a forged forwarding header must fail from the public listener.
        assert server.succeed(web("/example.txt?delete", account="manager:manager-test", extra="-X POST -H 'X-Forwarded-For: 192.168.1.2' -o /dev/null -w '%{http_code}'")).strip() in ("401", "403", "404")
        assert server.succeed(web("/example.txt?delete", account="manager:manager-test", extra="-X POST --interface 192.168.1.1 -o /dev/null -w '%{http_code}'")).strip() in ("401", "403", "404")
        server.succeed(web("/example.txt?delete", account="manager:manager-test", internal=True, extra="--fail -X POST"))

    with subtest("public CouchDB requires its database-scoped account and blocks server administration"):
        assert server.succeed(web("/obsidian", account="", host="obsidian.test", extra="-o /dev/null -w '%{http_code}'")).strip() == "401"
        server.succeed(web("/obsidian", account="livesync:livesync-test", host="obsidian.test", extra="--fail"))
        server.succeed(web("/obsidian", account="livesync:livesync-test", internal=True, host="obsidian.test", extra="--fail"))
        assert server.succeed(web("/_users", account="livesync:livesync-test", internal=True, host="obsidian.test", extra="-o /dev/null -w '%{http_code}'")).strip() in ("401", "403")
        assert server.succeed(web(account="manager:manager-test", host="files-internal.test", extra="-o /dev/null -w '%{http_code}'")).strip() == "403"
        server.succeed(web(account="manager:manager-test", host="files-internal.test", internal=True, extra="--fail"))

    with subtest("database bootstrap waits for API readiness during a running-system restart"):
        server.succeed("systemctl restart couchdb.service personal-storage-couchdb-init.service")
        server.succeed(web("/obsidian", account="livesync:livesync-test", host="obsidian.test", extra="--fail"))

    with subtest("quota changes apply online without restarting either application"):
        pids = server.succeed("systemctl show -p MainPID copyparty couchdb")
        for limit in (72, 64):
            code = "import json; p=json.load(open('/run/personal-storage/config.json')); p['quota_bytes']=" + str(limit * 1024 * 1024) + "; json.dump(p,open('/run/resize.json','w'))"
            server.succeed("python3 -c " + shlex.quote(code))
            server.succeed("python3 ${../hosts/lib/personal-storage.py} --config /run/resize.json initialize")
            code = "import json,sys; assert json.load(sys.stdin)['quota_bytes'] == " + str(limit * 1024 * 1024)
            server.wait_until_succeeds("personal-storage-status | python3 -c " + shlex.quote(code))
            assert server.succeed("systemctl show -p MainPID copyparty couchdb") == pids

    with subtest("OpenSSH SFTP shares the web files; expiry ignores preserved client mtimes"):
        server.succeed('ssh-keygen -q -t ed25519 -N "" -f /run/transfer-test-key')
        server.wait_for_open_port(2222, "192.168.1.1")
        server.succeed("echo sftp-fixture > /run/sftp.txt; touch -d 2000-01-01 /run/sftp.txt")
        try:
            server.succeed("scp -p -P 2222 -i /run/transfer-test-key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /run/sftp.txt copyparty@192.168.1.1:/files/")
        except Exception:
            print(server.succeed("personal-storage-logs -u copyparty -n 80 --no-pager"))
            raise
        assert server.succeed(web("/sftp.txt", extra="--fail")).strip() == "sftp-fixture"
        server.succeed("scp -P 2222 -i /run/transfer-test-key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null copyparty@192.168.1.1:/files/sftp.txt /run/sftp-roundtrip.txt")
        server.succeed("cmp /run/sftp.txt /run/sftp-roundtrip.txt")
        # SSHFS-style random writes, truncation and rename must preserve data.
        code = (
            "import paramiko; c=paramiko.SSHClient(); c.set_missing_host_key_policy(paramiko.AutoAddPolicy()); "
            "c.connect('192.168.1.1',port=2222,username='copyparty',key_filename='/run/transfer-test-key'); s=c.open_sftp(); assert s.listdir('/')==['files']; "
            "f=s.open('/files/random-access.txt','wb'); f.write(b'original-content'); f.close(); "
            "f=s.open('/files/random-access.txt','r+'); f.seek(3); f.write(b'X'); f.close(); "
            "s.truncate('/files/random-access.txt',8); assert s.open('/files/random-access.txt').read()==b'oriXinal'; "
            "s.rename('/files/random-access.txt','/files/renamed.txt'); s.remove('/files/renamed.txt'); c.close()"
        )
        server.succeed("${sftpPython}/bin/python3 -c " + shlex.quote(code))
        server.succeed("systemctl start personal-storage-expire.service")
        server.succeed(web("/sftp.txt", extra="--fail"))
        server.succeed("touch -d 2099-01-01 /srv/personal-services/transfer/sftp.txt")
        time.sleep(7)
        server.succeed("systemctl start personal-storage-expire.service")
        server.fail("test -f /srv/personal-services/transfer/sftp.txt")

    with subtest("SFTP cannot consume the database maintenance reserve and reports failed writes"):
        server.succeed("dd if=/dev/zero of=/run/large.bin bs=1M count=64 status=none")
        server.fail("scp -P 2222 -i /run/transfer-test-key -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null /run/large.bin copyparty@192.168.1.1:/files/")
        # ext4 delayed allocation reservations enforce quotas before appearing
        # in quotactl's allocated-space statistics.
        server.succeed("sync -f /srv/personal-services/transfer/large.bin")
        print(server.succeed("personal-storage-status"))
        server.succeed("test $(stat -c %s /srv/personal-services/transfer/large.bin) -gt 33554432")
        code = "import json,sys; s=json.load(sys.stdin); assert s['used_bytes'] > 32*1024*1024; assert s['quota_bytes']-s['used_bytes'] >= 12*1024*1024"
        server.wait_until_succeeds("personal-storage-status | python3 -c " + shlex.quote(code), timeout=15)
        server.succeed("runuser -u couchdb -- dd if=/dev/zero of=/srv/personal-services/couchdb/maintenance-test bs=1M count=4 status=none")
        server.succeed("rm /srv/personal-services/transfer/large.bin /srv/personal-services/couchdb/maintenance-test")

    with subtest("aggregate quota stops both service users while the rest of the disk remains free"):
        server.succeed("systemctl stop copyparty.service personal-storage-sftp.service couchdb.service personal-storage-budget.service")
        server.succeed("setquota -u copyparty 0 0 0 0 /srv")
        server.succeed("runuser -u copyparty -- dd if=/dev/zero of=/srv/personal-services/transfer/share-a bs=1M count=8 status=none")
        output = server.fail("runuser -u couchdb -- dd if=/dev/zero of=/srv/personal-services/couchdb/share-b bs=1M count=64 2>&1")
        assert "quota" in output.lower(), output
        server.succeed("test $(df --output=avail -k /srv | tail -n1) -gt 65536")
        # An unsafe reduction must be rejected before any new limit is installed.
        server.succeed("${pkgs.python3}/bin/python3 -c 'import json; p=json.load(open(\"/run/personal-storage/config.json\")); p[\"quota_bytes\"]=1024; json.dump(p,open(\"/run/shrink.json\",\"w\"))'")
        error = server.fail("${pkgs.python3}/bin/python3 ${../hosts/lib/personal-storage.py} --config /run/shrink.json initialize 2>&1")
        assert "refusing to shrink" in error, error
        server.succeed("rm /srv/personal-services/transfer/share-a /srv/personal-services/couchdb/share-b")
        server.succeed("systemctl restart personal-storage-budget.service")
  '';
}
