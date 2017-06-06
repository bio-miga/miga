#!/bin/bash
set -e
#MIGA=${MIGA:-$(cd "$(dirname "$0")/.."; pwd)}
# shellcheck source=/dev/null
source "$HOME/.miga_rc"
export PATH="$MIGA/bin:$MIGA/utils/enveomics/Scripts:$PATH"
SCRIPT=${SCRIPT:-$(basename "$0" .bash)}

function exists { [[ -e "$1" ]] ; }
function fx_exists { [[ $(type -t "$1") == "function" ]] ; }

for i in $(miga plugins -P "$PROJECT") ; do
  # shellcheck source=/dev/null
  source "$i/scripts-plugin.bash"
done

#if [[ "$RUNTYPE" == "qsub" ]] ; then
#elif [[ "$RUNTYPE" == "msub" ]] ; then
#fi

