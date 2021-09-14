#!/bin/bash

###
# Setup environment
set -e
MIGA_MOD="${MIGA_HOME:-"$HOME"}/.miga_modules"
[[ -s "$MIGA_MOD" ]] && . "$MIGA_MOD"
eval "$("$MIGA/bin/miga" env)"
SCRIPT=${SCRIPT:-"$(basename "$0" .bash)"}

###
# Ancillary functions

# Evaluates if the first passed argument is an existing file
function exists { [[ -e "$1" ]] ; }

# Evaluates if the first passed argument is a function
function fx_exists { [[ $(type -t "$1") == "function" ]] ; }

# Initiate a project-wide run
function miga_start_project_step {
  local dir="$1"
  local dir_r="${dir}.running"
  mkdir -p "$dir"
  mkdir -p "$dir_r"
  cd "$dir_r"
  miga date > "miga-project.start"
}

# Finalize a project-wide run
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
  echo "# Host: $(hostname) [$CORES]"
  echo "# MiGA: $MIGA"
  echo "# Project: $PROJECT"
  if [[ -n $DATASET ]] ; then
    echo "# Dataset: $DATASET"
    miga edit -P "$PROJECT" -D "$DATASET" -m "_step=$SCRIPT"
  fi
  echo '#------------'
fi

true
