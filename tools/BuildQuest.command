#!/bin/zsh
set -eu
cd -- "$(dirname -- "$0")/.."
python3 tools/quest.py build
print "APK: $PWD/artifacts/OpenSaberPlus-Quest2-0.8.0-dev.apk"
