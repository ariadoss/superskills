#!/bin/bash
set -e
mkdir -p ./fixture-repo
git -C "/Users/danilosapad/Sites/hyperion360" archive HEAD | tar -x -C ./fixture-repo
cp -R /tmp/graphify-vendor ./graphify-vendor 2>/dev/null || python3.11 -m pip install graphifyy --target ./graphify-vendor --quiet
