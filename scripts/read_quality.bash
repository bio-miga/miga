#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES, $DATASET
set -e
SCRIPT="read_quality"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/03.read_quality"

# Initialize
miga date > "$DATASET.start"

# Gzip (if necessary)
for s in 1 2 ; do
  in="../02.trimmed_reads/${DATASET}.${s}.clipped.fastq"
  if [[ -s "$in" ]] ; then
    gzip -9f "$in"
    miga add_result -P "$PROJECT" -D "$DATASET" -r trimmed_reads -f
  fi
done

# Finalize
miga date > "${DATASET}.done"
cat <<VERSIONS \
  | miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT" -f --stdin-versions
=> MiGA
$(miga --version)
VERSIONS

