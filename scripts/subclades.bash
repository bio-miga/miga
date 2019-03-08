#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
set -e
SCRIPT="subclades"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/10.clades/02.ani"

# Initialize
miga date > "miga-project.start"

# Run R code
ruby -I "$MIGA/lib" "$MIGA/utils/subclades.rb" "$PROJECT" "$SCRIPT"

# Finalize
miga date > "miga-project.done"
miga add_result -P "$PROJECT" -r "$SCRIPT" -f
