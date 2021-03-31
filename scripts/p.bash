#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
set -e
SCRIPT="p"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1

while true ; do
  res="$(miga next_step -P "$PROJECT")"
  [[ "$res" == '?' ]] && break
  miga run -P "$PROJECT" -r "$res" -t "$CORES"
  if [[ "$res" == "$last_res" ]] ; then
    let k=$k+1
    if [[ $k -gt 10 ]] ; then
      miga edit -P "$PROJECT" \
        -m "run_$res=false,warn=Too many failed attempts to run $res"
    fi
  else
    k=0
    last_res=$res
  fi
done

