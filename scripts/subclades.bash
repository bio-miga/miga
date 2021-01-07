#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
set -e
SCRIPT="subclades"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
DIR="$PROJECT/data/10.clades/02.ani"

# Initialize
miga_start_project_step "$DIR"

# Run
ruby -I "$MIGA/lib" "$MIGA/utils/subclades.rb" "$PROJECT" "$SCRIPT"

# Finalize
miga_end_project_step "$DIR"
