#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES, $DATASET
set -e
SCRIPT="distances"
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
# shellcheck source=scripts/miga.bash
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/09.distances"

# Initialize
miga date > "$DATASET.start"

# Run
ruby -I "$MIGA/lib" "$MIGA/utils/distances.rb" "$PROJECT" "$DATASET"

# Finalize
rm -R "$TMPDIR"
miga date > "$DATASET.done"
miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT"
