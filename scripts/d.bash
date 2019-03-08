#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES, $DATASET
set -e
SCRIPT="d"
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
# shellcheck source=scripts/miga.bash
source "$MIGA/scripts/miga.bash" || exit 1

while true ; do
  res="$(miga next_step -P "$PROJECT" -D "$DATASET")"
  [[ "$res" == "?" ]] && break
  miga run -P "$PROJECT" -D "$DATASET" -r "$SCRIPT" -t "$CORES"
done

