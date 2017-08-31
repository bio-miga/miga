#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES, $DATASET
set -e
SCRIPT="distances"
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
# shellcheck source=scripts/miga.bash
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/09.distances"

# Initialize
miga date > "$DATASET.start"
TMPDIR=$(mktemp -d /tmp/MiGA.XXXXXXXXXXXX)
trap "rm -rf '$TMPDIR'; exit" SIGHUP SIGINT SIGTERM

# Check type of dataset
NOMULTI=$(miga ls -P "$PROJECT" -D "$DATASET" --no-multi \
  | wc -l | awk '{print $1}')
REF=$(miga ls -P "$PROJECT" -D "$DATASET" --ref \
  | wc -l | awk '{print $1}')

# Call submodules
# shellcheck source=scripts/_distances_functions.bash
source "$MIGA/scripts/_distances_functions.bash"
if [[ "$NOMULTI" -eq "1" && "$REF" -eq "1" ]] ; then
  # shellcheck source=scripts/_distances_ref_nomulti.bash
  source "$MIGA/scripts/_distances_ref_nomulti.bash"
elif [[ "$NOMULTI" -eq "1" ]] ; then
  S_PROJ=$PROJECT
  # shellcheck source=scripts/_distances_noref_nomulti.bash
  source "$MIGA/scripts/_distances_noref_nomulti.bash"
fi

# Finalize
rm -R "$TMPDIR"
miga date > "$DATASET.done"
miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT"
