#!/bin/bash

# Setup environment
set -e
MIGA_HOME=${MIGA_HOME:-"$HOME"}
SCRIPT=${SCRIPT:-$(basename "$0" .bash)}
# shellcheck source=/dev/null
. "$MIGA_HOME/.miga_rc"

# Ensure MiGA & submodules are first in PATH
export PATH="$MIGA/bin:$PATH"
for util in enveomics/Scripts FastAAI/FastAAI multitrim ; do
  export PATH="$MIGA/utils/$util:$PATH"
done

# Ancillary functions
function exists { [[ -e "$1" ]] ; }
function fx_exists { [[ $(type -t "$1") == "function" ]] ; }
function miga_start_project_step {
  local dir="$1"
  local dir_r="${dir}.running"
  mkdir -p "$dir"
  mkdir -p "$dir_r"
  cd "$dir_r"
  miga date > "miga-project.start"
}
function miga_end_project_step {
  local dir="$1"
  local dir_r="${dir}.running"
  cd "$dir"
  rm -rf miga-project.*
  mv "$dir_r"/miga-project.* .
  rmdir "$dir_r" &>/dev/null || true
  miga date > "miga-project.done"
  miga add_result -P "$PROJECT" -r "$SCRIPT" -f
}

# Environment header
if [[ "$SCRIPT" != "d" && "$SCRIPT" != "p" ]] ; then
  echo ""
  echo "######[ $SCRIPT ]######"
  echo "# Date: $(miga date)"
  echo "# Host: $(hostname)"
  echo "# MiGA: $MIGA"
  echo "# Project: $PROJECT"
  if [[ -n $DATASET ]] ; then
    echo "# Dataset: $DATASET"
    miga edit -P "$PROJECT" -D "$DATASET" -m "_step=$SCRIPT"
  fi
  echo '#------------'
fi

true
