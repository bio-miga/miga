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

# Clean Prodigal noisy deflines
for i in faa fna ; do
  perl -pe 's/>.*ID=([^;]+);.*/>gene_$1/' "$DATASET.$i" > "$DATASET.$i.t"
  mv "$DATASET.$i.t" "$DATASET.$i"
done
perl -pe 's/\tID=(\d+_\d+);/\tID=gene_$1;/' "$DATASET.gff3" > "$DATASET.gff3.t"
mv "$DATASET.gff3.t" "$DATASET.gff3"

# Gzip
gzip -9 -f "$DATASET.gff3"

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.done"
miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT"
