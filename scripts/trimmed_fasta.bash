#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES, $DATASET
set -e
SCRIPT="trimmed_fasta"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/04.trimmed_fasta"

b=$DATASET

# Initialize
miga date > "$DATASET.start"

# FastQ -> FastA
for s in 1 2 ; do
  in="../02.trimmed_reads/${b}.${s}.clipped.fastq.gz"
  [[ -s "$in" ]] \
    && FastQ.maskQual.rb -i "$in" -o "${b}.${s}.fasta" --fasta --qual 18
done

# Interpose
if [[ -e "${b}.2.fasta" ]] ; then
  FastA.interpose.pl "${b}.CoupledReads.fa" "$b".[12].fasta
else
  mv "${b}.1.fasta" "${b}.SingleReads.fa"
fi

# Gzip
for x in 1.fasta 2.fasta SingleReads.fa CoupledReads.fa ; do
  in="${b}.${x}"
  [[ -e "$in" ]] && gzip -9f "$in"
done

# Finalize
miga date > "$DATASET.done"
miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT" -f

