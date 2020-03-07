#!/bin/bash
set -e
#MIGA=${MIGA:-$(cd "$(dirname "$0")/.."; pwd)}
MIGA_HOME=${MIGA_HOME:-"$HOME"}
# shellcheck source=/dev/null
. "$MIGA_HOME/.miga_rc"
export PATH="$MIGA/bin:$MIGA/utils/enveomics/Scripts:$PATH"
SCRIPT=${SCRIPT:-$(basename "$0" .bash)}

function exists { [[ -e "$1" ]] ; }
function fx_exists { [[ $(type -t "$1") == "function" ]] ; }

if [[ "$SCRIPT" != "d" && "$SCRIPT" != "p" ]] ; then
  echo '############'
  echo -n "Date: " ; miga date
  echo "Hostname: $(hostname)"
  echo "MiGA: $MIGA"
  echo "Task: $SCRIPT"
  echo "Project: $PROJECT"
  if [[ -n $DATASET ]] ; then
    echo "Dataset: $DATASET"
    miga edit -P "$PROJECT" -D "$DATASET" -m "_step=$SCRIPT"
  fi
  echo '------------'
fi

true
