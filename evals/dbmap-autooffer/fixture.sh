#!/bin/bash
. "$(dirname "$0")/../_lib/db-fixture.sh"
db_fixture "$PWD/fixture-repo"
