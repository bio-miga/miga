#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/10.clades/01.find"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "miga.project.start"

# Markov-cluster genomes by ANI
gunzip -c ../09.distances/03.ani/miga.project.txt.gz | tail -n+2 | awk -F'\t' '{print $2"\t"$3"\t"$4}' > genome-genome.aai90.rbm
ogs.mcl.rb -d . -o miga-project.ani-clades -t "$CORES" -i -f '(\S+)-(\S+)\.aai90\.rbm'
cat genome-genome.rbm | awk -F'\t' '$3>=95' > genome-genome.ani95.rbm
ogs.mcl.rb -d . -o miga-project.ani95-clades -t "$CORES" -b -f '(\S+)-(\S+)\.ani95\.rbm'

# Propose clade projects
cat miga-project.ani95-clades | tail -n +2 | tr ',' '\t' | awk 'NF >= 5' > miga-project.proposed-clades

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "miga.project.done"
$MIGA/bin/add_result -P "$PROJECT" -r clade_finding

