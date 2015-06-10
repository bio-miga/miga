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
# The type might be useful in future versions of IDBA, but for now all supported types
# can be handled by IDBA-UD
# TYPE=$($MIGA/bin/list_datasets -P "$PROJECT" -D "$DATASET" --metadata "type" | awk '{print $2}')
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
FastA.length.pl $DATASET.AllContigs.fna | awk '$2>=1000{print $1}' | FastA.filter.pl /dev/stdin $DATASET.AllContigs.fna > $DATASET.LargeContigs.fna

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.done"
$MIGA/bin/add_result -P "$PROJECT" -D "$DATASET" -r assembly

