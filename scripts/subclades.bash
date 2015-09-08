#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
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

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "miga-project.done"
$MIGA/bin/add_result -P "$PROJECT" -r subclades

