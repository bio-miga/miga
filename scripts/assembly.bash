#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/05.assembly"

b=$DATASET

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.start"

# Assemble
FA="../04.trimmed_fasta/$DATASET.CoupledReads.fa"
[[ -e $FA ]] || FA="$FA.gz"
[[ -e $FA ]] || FA="../04.trimmed_fasta/$DATASET.SingleReads.fa"
[[ -e $FA ]] || FA="$FA.gz"
idba_ud --pre_correction -r "$FA" -o "$DATASET" --num_threads "$CORES"

# Clean
cd $DATASET
rm kmer graph-*.fa align-* local-contig-*.fa contig-*.fa
cd ..

# Extract
if [[ -s $DATASET/scaffold.fa ]] ; then
   ln -s $DATASET/scaffold.fa $DATASET.AllContigs.fna
else
   ln -s $DATASET/contig.fa $DATASET.AllContigs.fna
fi
FastA.length.pl $DATASET.AllContigs.fna | awk '$2>=1000{print $1}' \
   | FastA.filter.pl /dev/stdin $DATASET.AllContigs.fna \
   > $DATASET.LargeContigs.fna

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.done"
miga add_result -P "$PROJECT" -D "$DATASET" -r assembly

