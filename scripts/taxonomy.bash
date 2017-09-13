#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES, $DATASET
set -e
SCRIPT="taxonomy"
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
# shellcheck source=scripts/miga.bash
source "$MIGA/scripts/miga.bash" || exit 1
DIR="$PROJECT/data/09.distances/05.taxonomy"
[[ -d "$DIR" ]] || mkdir -p "$DIR"
cd "$DIR"

# Initialize
miga date > "$DATASET.start"

# Check if there is a reference project
S_PROJ=$(miga about -P "$PROJECT" -m ref_project)

if [[ "$S_PROJ" != "?" ]] ; then

  # Check type of dataset
  NOMULTI=$(miga ls -P "$PROJECT" -D "$DATASET" --no-multi \
    | wc -l | awk '{print $1}')

  if [[ "$NOMULTI" -eq "1" ]] ; then
    # Call submodules
    TMPDIR=$(mktemp -d /tmp/MiGA.XXXXXXXXXXXX)
    trap "rm -rf '$TMPDIR'; exit" SIGHUP SIGINT SIGTERM
    # shellcheck source=scripts/_distances_functions.bash
    source "$MIGA/scripts/_distances_functions.bash"
    # shellcheck source=scripts/_distances_noref_nomulti.bash
    source "$MIGA/scripts/_distances_noref_nomulti.bash"
    rm -R "$TMPDIR"
  fi

fi

# Finalize
miga date > "$DATASET.done"
miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT"
