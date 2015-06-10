#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/07.annotation/01.function/01.essential"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.start"

# Find and extract essential genes
mkdir "$DATASET.ess"
TYPE=$($MIGA/bin/list_datasets -P "$PROJECT" -D "$DATASET" --metadata "type" | awk '{print $2}')
if [[ "$TYPE" == "metagenome" || "$TYPE" == "virome" ]] ; then
   HMM.essential.rb -i "../../../06.cds/$DATASET.faa" -o "$DATASET.ess.faa" -m "$DATASET.ess/" -t "$CORES" -r "$DATASET" --metagenome > "$DATASET.ess/log"
else
   HMM.essential.rb -i "../../../06.cds/$DATASET.faa" -o "$DATASET.ess.faa" -m "$DATASET.ess/" -t "$CORES" -r "$DATASET" > "$DATASET.ess/log"
fi

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.done"
$MIGA/bin/add_result -P "$PROJECT" -D "$DATASET" -r essential

