#!/bin/bash
set -e
#MIGA=$(cd "$(dirname "$0")/.."; pwd)
source "$HOME/.miga_rc"

function exists { [[ -e "$1" ]] ; }

#if [[ "$RUNTYPE" == "qsub" ]] ; then
#elif [[ "$RUNTYPE" == "msub" ]] ; then
#fi

