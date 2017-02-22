#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
set -e
SCRIPT="essential"
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/07.annotation/01.function/01.essential"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.start"
FAA="../../../06.cds/$DATASET.faa"

# Check if there are any proteins
if [[ ! -s $FAA ]] ; then
  echo Empty protein set, bypassing essential genes
  rm "$DATASET.start"
  miga create_dataset -P "$PROJECT" -D $DATASET \
    -m run_essential_genes=false --update
  exit 0
fi

# Find and extract essential genes
[[ -d "$DATASET.ess" ]] && rm -R "$DATASET.ess"
mkdir "$DATASET.ess"
TYPE=$(miga list_datasets -P "$PROJECT" -D "$DATASET" \
   --metadata "type" | awk '{print $2}')
if [[ "$TYPE" == "metagenome" || "$TYPE" == "virome" ]] ; then
   HMM.essential.rb -i "$FAA" -o "$DATASET.ess.faa" \
      -m "$DATASET.ess/" -t "$CORES" -r "$DATASET" --metagenome \
      > "$DATASET.ess/log"
else
   HMM.essential.rb -i "$FAA" -o "$DATASET.ess.faa" \
      -m "$DATASET.ess/" -t "$CORES" -r "$DATASET" \
      > "$DATASET.ess/log"
fi

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.done"
miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT"
