#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES, $DATASET
set -e
SCRIPT="distances"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/09.distances"

# Initialize
miga date > "$DATASET.start"

# Check quality
miga stats -P "$PROJECT" -D "$DATASET" -r essential_genes --compute-and-save
inactive=$(miga ls -P "$PROJECT" -D "$DATASET" -m inactive | cut -f 2)
[[ "$inactive" == "true" ]] && exit

# Run distances
ruby -I "$MIGA/lib" "$MIGA/utils/distances.rb" "$PROJECT" "$DATASET"

# Finalize
miga date > "$DATASET.done"
miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT" -f
