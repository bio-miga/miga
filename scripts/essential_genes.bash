#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES, $DATASET
set -e
SCRIPT="essential_genes"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/07.annotation/01.function/01.essential"

# Initialize
miga date > "${DATASET}.start"
FAA="../../../06.cds/${DATASET}.faa"
[[ -s "$FAA" ]] || FAA="${FAA}.gz"

# Check if there are any proteins
if [[ ! -s $FAA ]] ; then
  echo Empty protein set, bypassing essential genes
  rm "${DATASET}.start"
  miga edit -P "$PROJECT" -D "$DATASET" -m run_essential_genes=false
  exit 0
fi

# Find and extract essential genes
[[ -d "${DATASET}.ess" ]] && rm -R "${DATASET}.ess"
mkdir "${DATASET}.ess"
TYPE=$(miga ls -P "$PROJECT" -D "$DATASET" \
  --metadata "type" | awk '{print $2}')
COLL=$(miga option -P "$PROJECT" --key ess_coll)
if [[ "$TYPE" == "metagenome" || "$TYPE" == "virome" ]] ; then
  FLAGS="--metagenome"
else
  FLAGS="--alignments ${DATASET}.ess/proteins.aln"
fi
HMM.essential.rb \
  -i "$FAA" -o "${DATASET}.ess.faa" -m "${DATASET}.ess/" \
  -t "$CORES" -r "$DATASET" --collection "$COLL" $FLAGS \
  > "${DATASET}.ess/log"

# Reduce files
if exists "$DATASET".ess/*.faa ; then
  ( cd "${DATASET}.ess" \
      && tar -zcf proteins.tar.gz *.faa \
      && rm *.faa )
fi

# Finalize
miga date > "${DATASET}.done"
miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT" -f
