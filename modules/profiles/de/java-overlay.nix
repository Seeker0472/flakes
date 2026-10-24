final: prev:
let
  jdk = prev.jetbrains.jdk-no-jcef;
  runtime = prev.symlinkJoin {
    name = "java-wayland-${jdk.version}";
    inherit (jdk) version;
    paths = [ jdk ];
    nativeBuildInputs = [ prev.makeWrapper ];
    postBuild = ''
      # bin is already a relative symlink to lib/openjdk/bin, so replacing the
      # JAVA_HOME launcher also covers PATH without rebuilding the JDK.
      rm "$out/lib/openjdk/bin/java" "$out/nix-support/setup-hook"
      makeWrapper ${jdk}/bin/java "$out/lib/openjdk/bin/java" \
        --add-flags '-Dawt.toolkit.name=auto'
      substitute ${jdk}/nix-support/setup-hook "$out/nix-support/setup-hook" \
        --replace-fail '${jdk}' "$out"
    '';
    passthru = jdk.passthru // {
      home = "${runtime}/lib/openjdk";
    };
    meta = jdk.meta // {
      description = "JetBrains Java runtime with automatic Wayland selection";
    };
  };
in
{
  java-wayland = runtime;
  # Applications such as Logisim already accept jre. Keep their upstream
  # launchers, desktop files and icons, and leave build JDKs/versioned JVMs alone.
  jre = final.java-wayland;

  # This C++ library only uses Java to generate test metadata at build time.
  # Keep its original build dependency so a desktop runtime change does not
  # invalidate evolution-data-server, GNOME Shell and the GDM session closure.
  libphonenumber = prev.libphonenumber.override { jre = prev.jre; };
}
