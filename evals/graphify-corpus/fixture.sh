#!/bin/bash
set -e
mkdir -p ./fixture-repo
git -C "$HOME/Sites/songs" archive HEAD | tar -x -C ./fixture-repo
printf 'PYTHONPATH=%s/fixture-repo/../graphify-vendor\n' "$PWD" > ./fixture-repo/.graphify_env_hint
cp -R /tmp/graphify-vendor ./graphify-vendor 2>/dev/null || python3.11 -m pip install graphifyy --target ./graphify-vendor --quiet
