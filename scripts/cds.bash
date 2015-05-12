#!/bin/bash
# Available variables: $PROJECT, $DATASET, $RUNTYPE
source "$(dirname "$0")/miga.bash" # Available variables: $CORES, $MIGA
cd "$PROJECT/data/06.cds"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.start"
GM=$(which gmhmmp)

# Register key
if [[ ! -e .gm_key ]] ; then
   if [[ -e "$GM/.gm_key" ]] ; then
      cp "$GM/.gm_key" .
   else
      cp "$HOME/.gm_key" .
   fi
fi

# Run MetaGeneMark
gmhmmp -a -d -m "$GM/MetaGeneMark_v1.mod" -f G -o "$DATASET.gff2" "../05.assembly/$DATASET.LargeContigs.fna"

# Extract
perl "$GM/aa_from_gff.pl" < "$DATASET.gff2" > "$DATASET.faa"
perl "$GM/nt_from_gff.pl" < "$DATASET.gff2" > "$DATASET.fna"

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.done"
$MIGA/bin/add_result -P "$PROJECT" -D "$DATASET" -r cds

