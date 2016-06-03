#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
set -e
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/05.assembly"

b=$DATASET

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.start"

# Interpose (if needed)
TF="../04.trimmed_fasta"
if [[ -s $TF/$DATASET.1.fasta \
      && -s $TF/$DATASET.2.fasta \
      && ! -s $TF/$DATASET.CoupledReads.fa ]] ; then
  FastA.interpose.pl $TF/$DATASET.CoupledReads.fa $TF/$DATASET.[12].fasta
  gzip -9 -f $TF/$DATASET.1.fasta
  gzip -9 -f $TF/$DATASET.2.fasta
  miga add_result -P "$PROJECT" -D "$DATASET" -r trimmed_fasta
fi

# Assemble
FA="$TF/$DATASET.CoupledReads.fa"
[[ -e $FA ]] || FA="$FA.gz"
[[ -e $FA ]] || FA="../04.trimmed_fasta/$DATASET.SingleReads.fa"
[[ -e $FA ]] || FA="$FA.gz"
RD="r"
[[ $FA == *.SingleReads.fa* ]] && RD="l"
idba_ud --pre_correction -$RD "$FA" -o "$DATASET" --num_threads "$CORES" || true
[[ -s $DATASET/contig.fa ]] || exit 1

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
