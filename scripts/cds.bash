#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES, $DATASET
set -e
SCRIPT="cds"
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/06.cds"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.start"

# Run Prodigal
TYPE=$(miga list_datasets -P "$PROJECT" -D "$DATASET" \
   --metadata "type" | awk '{print $2}')
case "$TYPE" in
  metagenome|virome) PROCEDURE=meta ;;
  *) PROCEDURE=single ;;
esac
prodigal -a "$DATASET.faa" -d "$DATASET.fna" -f gff -o "$DATASET.gff3" \
  -p $PROCEDURE -q -i "../05.assembly/$DATASET.LargeContigs.fna"

# Gzip
gzip -9 -f "$DATASET.gff3"

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.done"
miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT"
