#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
set -e
SCRIPT="haai_distances"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
DIR="$PROJECT/data/09.distances/01.haai"

# Initialize
miga_start_project_step "$DIR"

# Cleanup databases
ruby -I "$MIGA/lib" "$MIGA/utils/cleanup-databases.rb" "$PROJECT" "$CORES"

# No real need for hAAI distributions at all
echo -n "" > miga-project.log
echo -n "" > miga-project.txt
echo "aai <- NULL; save(aai, file = 'miga-project.Rdata')" | R --vanilla

# Finalize
miga_end_project_step "$DIR"
