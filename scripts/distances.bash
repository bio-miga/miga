#!/bin/bash
# Available variables: $PROJECT, $DATASET, $RUNTYPE, $MIGA, $CORES
set -e
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/09.distances"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.start"
TMPDIR=$(mktemp -d /tmp/MiGA.XXXXXXXXXXXX)
trap "rm -rf $TMPDIR; exit" SIGHUP SIGINT SIGTERM

# Check type of dataset
NOMULTI=$(miga list_datasets -P "$PROJECT" -D "$DATASET" --no-multi \
   | wc -l | awk '{print $1}')
REF=$(miga list_datasets -P "$PROJECT" -D "$DATASET" --ref \
   | wc -l | awk '{print $1}')

# Call submodules
source "$MIGA/scripts/_distances_functions.bash"
if [[ "$NOMULTI" -eq "1" && "$REF" -eq "1" ]] ; then
   source "$MIGA/scripts/_distances_ref_nomulti.bash"
elif [[ "$NOMULTI" -eq "1" ]] ; then
   source "$MIGA/scripts/_distances_noref_nomulti.bash"
fi

# Finalize
rm -R $TMPDIR
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.done"
miga add_result -P "$PROJECT" -D "$DATASET" -r distances

