#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
set -e
SCRIPT="maintenance"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1

miga doctor --only status -P "$PROJECT" -t "$CORES" -v

