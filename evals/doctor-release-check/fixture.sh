#!/bin/bash
# Everything linked; the Codex manifest was not re-stamped after the VERSION bump.
. "$(dirname "$0")/../_lib/doctor-fixture.sh"
doctor_fixture "tdd debug clean-code" "2.23.0"
