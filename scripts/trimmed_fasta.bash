#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES, $DATASET
set -e
SCRIPT="trimmed_fasta"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/04.trimmed_fasta"

b=$DATASET

# Initialize
miga date > "$DATASET.start"

# Gzip (if needed)
for x in 1.fasta 2.fasta SingleReads.fa CoupledReads.fa ; do
  in="${b}.${x}"
  [[ -e "$in" ]] && gzip -9f "$in"
done

# Finalize
echo 'Using FastQ directly' > "${DATASET}.empty"
miga date > "${DATASET}.done"
cat <<VERSIONS \
  | miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT" -f --stdin-versions
=> MiGA
$(miga --version)
VERSIONS

