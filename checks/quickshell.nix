{ pkgs }:
let
  quickshellSource = ../modules/profiles/de/quickshell;
in
pkgs.runCommand "quickshell-checks"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.qt6.qtdeclarative
    ];
  }
  ''
    export QT_QPA_PLATFORM=offscreen
    export HOME="$TMPDIR/home"
    export XDG_CACHE_HOME="$TMPDIR/cache"
    export FONTCONFIG_FILE=${pkgs.fontconfig.out}/etc/fonts/fonts.conf
    mkdir -p "$HOME" "$XDG_CACHE_HOME"
    qmllint \
      --import disable \
      --unqualified disable \
      --unused-imports disable \
      --uncreatable-type disable \
      -I ${pkgs.quickshell}/lib/qt-6/qml \
      -I ${pkgs.qt6.qtdeclarative}/lib/qt-6/qml \
      ${quickshellSource}/shell/*.qml
    qmltestrunner \
      -import ${quickshellSource}/shell \
      -import ${pkgs.qt6.qtdeclarative}/lib/qt-6/qml \
      -input ${quickshellSource}/tests
    python -m unittest discover \
      -s ${quickshellSource}/tests \
      -p 'test_*.py'
    touch "$out"
  ''
