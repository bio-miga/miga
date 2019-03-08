#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES, $DATASET
set -e
SCRIPT="d"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1

while true ; do
  res="$(miga next_step -P "$PROJECT" -D "$DATASET")"
  [[ "$res" == '?' ]] && break
  miga run -P "$PROJECT" -D "$DATASET" -r "$res" -t "$CORES"
done

