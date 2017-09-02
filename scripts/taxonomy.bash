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
    
    # Test taxonomy
    (
      trap 'rm "$DATASET.json" "$DATASET.done"' EXIT
      miga date > "$DATASET.done"
      miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT"
      miga tax_test -P "$PROJECT" -D "$DATASET" \
        --ref-project -t intax > "$DATASET.intax.txt"
    )
    
    # Transfer taxonomy
    TAX_PVALUE=$(miga about -P "$PROJECT" -m tax_pvalue)
    [[ "$TAX_PVALUE" == "?" ]] && TAX_PVALUE="0.05"
    NEW_TAX=$(tail -n +6 "$DATASET.intax.txt" | head -n -3 \
      | awk '$3<'$TAX_PVALUE'{print $1":"$2}' | grep -v "?" \
      | tr "\\n" ' ' | perl -pe 's/ *$//')
    miga tax_set -P "$PROJECT" -D "$DATASET" -s "$NEW_TAX"
  fi

fi

# Finalize
miga date > "$DATASET.done"
miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT"
