#!/bin/bash
# tdd and debug are linked; clean-code was added upstream and never linked.
. "$(dirname "$0")/../_lib/doctor-fixture.sh"
doctor_fixture "tdd debug" "2.24.0"
