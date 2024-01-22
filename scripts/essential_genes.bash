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
if [[ ! -s "$FAA" ]] ; then
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
  FLAGS=""
fi
HMM.essential.rb \
  -i "$FAA" -o "${DATASET}.ess.faa" -m "${DATASET}.ess/" \
  -t "$CORES" -r "$DATASET" --collection "$COLL" $FLAGS \
  > "${DATASET}.ess/log"

# Index for FastAAI and classify (if needed and possible)
NOMULTI=$(miga ls -P "$PROJECT" -D "$DATASET" --no-multi \
            | wc -l | awk '{print $1}')
if [[ "$NOMULTI" -eq "1" ]] ; then
  python3 "$MIGA/utils/FastAAI/fastaai/fastaai_miga_preproc.py" \
    --protein "$FAA" --output_crystal "${DATASET}.crystal" \
    --compress
  
  # Classify
  DOMAIN=$(miga ls -P "$PROJECT" -D "$DATASET" -m tax:d | cut -f 2)
  if [[ "$DOMAIN" == "?" ]] ; then
    REF_PROJ=$(miga db --list-local -n Phyla_Lite --tab | tail -n +2 | cut -f 5)
    echo "Phylum-level classification against $REF_PROJ"
    if [[ -n "$REF_PROJ" ]] ; then
      cp "${DATASET}.start" "${DATASET}.start.bak"
      miga date > "${DATASET}.done"
      miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT" -f
      ruby -I "$MIGA/lib" \
        "$MIGA/utils/distances.rb" "$PROJECT" "$DATASET" \
        run_taxonomy=1 only_domain=1 "ref_project=$REF_PROJ"
      mv "${DATASET}.start.bak" "${DATASET}.start"
      rm "${DATASET}.done" "${DATASET}.json"
    fi
  fi
fi

# Reduce files
if exists "$DATASET".ess/*.faa ; then
  ( cd "${DATASET}.ess" \
      && tar -zcf proteins.tar.gz *.faa \
      && rm *.faa )
fi

# Finalize
miga date > "${DATASET}.done"
cat <<VERSIONS \
  | miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT" -f --stdin-versions
=> MiGA
$(miga --version)
=> Enveomics Collection: HMM.essential.rb
$(HMM.essential.rb --version 2>&1 | perl -pe 's/.*: //')
$(
  if [[ "$NOMULTI" -eq "1" ]] ; then
    echo "=> FastAAI"
    fastaai version 2>&1 | perl -pe 's/.*=//'
  fi
)
VERSIONS

