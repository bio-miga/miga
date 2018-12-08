#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
set -e
SCRIPT="clade_finding"
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
# shellcheck source=scripts/miga.bash
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/10.clades/01.find"

# Initialize
miga date > "miga-project.start"

# Run
ruby -I "$MIGA/lib" "$MIGA/utils/subclades.rb" "$PROJECT" "$SCRIPT"

# Finalize
miga date > "miga-project.done"
miga add_result -P "$PROJECT" -r "$SCRIPT" -f
