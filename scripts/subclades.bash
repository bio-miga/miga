#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
set -e
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/10.clades/02.ani"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "miga-project.start"

# Run R code
echo "
source('$MIGA/utils/subclades.R');
subclades('../../09.distances/03.ani/miga-project.txt.gz',
   'miga-project', $CORES);
" | R --vanilla

# Compile
ruby "$MIGA/utils/subclades-compile.rb" . \
   >  miga-project.class.tsv \
   2> miga-project.class.nwk

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "miga-project.done"
miga add_result -P "$PROJECT" -r subclades

