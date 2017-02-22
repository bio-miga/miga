#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
set -e
SCRIPT="cds"
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/06.cds"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.start"
GM=$(dirname -- $(which gmhmmp))

# Register key
if [[ ! -e .gm_key ]] ; then
   if [[ -e "$GM/gm_key" ]] ; then
      cp "$GM/gm_key" ".gm_key"
   elif [[ -e "$GM/gm_key_64" ]] ; then
      cp "$GM/gm_key_64" ".gm_key"
   elif [[ -e "$GM/gm_key_32" ]] ; then
      cp "$GM/gm_key_32" ".gm_key"
   elif [[ -e "$GM/.gm_key" ]] ; then
      cp "$GM/.gm_key" ".gm_key"
   elif [[ -e "$HOME/.gm_key" ]] ; then
      cp "$HOME/.gm_key" .
   else
      echo "Impossible to find MetaGeneMark key, please register your copy" \
	 "and place the key in '$GM/gm_key'." >&2
      exit 1
   fi
fi

# Run MetaGeneMark
gmhmmp -a -d -m "$GM/MetaGeneMark_v1.mod" -f G -o "$DATASET.gff2" \
   "../05.assembly/$DATASET.LargeContigs.fna"

# Extract
perl "$GM/aa_from_gff.pl" < "$DATASET.gff2" > "$DATASET.faa"
perl "$GM/nt_from_gff.pl" < "$DATASET.gff2" > "$DATASET.fna"

# Gzip
gzip -9 -f "$DATASET.gff2"

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.done"
miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT"
