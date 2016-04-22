#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
set -e
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/10.clades/01.find"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "miga-project.start"

# Markov-cluster genomes by ANI
gunzip -c ../../09.distances/03.ani/miga-project.txt.gz | tail -n+2 \
  | awk -F"\\t" '$4>=90{print $2"'"\\t"'"$3"'"\\t"'"$4}' \
  > genome-genome.aai90.rbm
ogs.mcl.rb -d . -o miga-project.aai90-clades -t "$CORES" -i \
  -f "(\\S+)-(\\S+)\\.aai90\\.rbm"
rm genome-genome.aai90.rbm
gunzip -c ../../09.distances/02.aai/miga-project.txt.gz | tail -n+2 \
  | awk -F"\\t" '$4>=95{print $2"'"\\t"'"$3"'"\\t"'"$4}' \
  > genome-genome.ani95.rbm
ogs.mcl.rb -d . -o miga-project.ani95-clades -t "$CORES" -b \
  -f "(\\S+)-(\\S+)\\.ani95\\.rbm"
rm genome-genome.ani95.rbm

# Propose clade projects
cat miga-project.ani95-clades | tail -n +2 | tr "," "\\t" | awk 'NF >= 5' \
  > miga-project.proposed-clades

# Run R code
echo "
source('$MIGA/utils/subclades.R');
subclades('../../09.distances/02.aai/miga-project.txt.gz',
  'miga-project', $CORES);
" | R --vanilla
mv miga-project.ani.nwk miga-project.aai.nwk

# Compile
ruby "$MIGA/utils/subclades-compile.rb" . \
  >  miga-project.class.tsv \
  2> miga-project.class.nwk

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "miga-project.done"
miga add_result -P "$PROJECT" -r clade_finding
