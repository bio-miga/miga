#!/bin/bash
set -e
#MIGA=${MIGA:-$(cd "$(dirname "$0")/.."; pwd)}
source "$HOME/.miga_rc"
export PATH="$MIGA/bin:$PATH"

function exists { [[ -e "$1" ]] ; }

#if [[ "$RUNTYPE" == "qsub" ]] ; then
#elif [[ "$RUNTYPE" == "msub" ]] ; then
#fi

