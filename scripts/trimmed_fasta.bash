#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES, $DATASET
set -e
SCRIPT="trimmed_fasta"
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
# shellcheck source=scripts/miga.bash
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/04.trimmed_fasta"

b=$DATASET

# Initialize
miga date > "$DATASET.start"

# Gunzip (if necessary)
for sis in 1 2 ; do
  [[ -e "../02.trimmed_reads/$b.$sis.clipped.fastq.gz" \
    && ! -e "../02.trimmed_reads/$b.$sis.clipped.fastq" ]] \
      && gunzip "../02.trimmed_reads/$b.$sis.clipped.fastq.gz"
done

# FastQ -> FastA
FQ2A="$MIGA/utils/enveomics/Scripts/FastQ.toFastA.awk"
awk -f "$FQ2A" < "../02.trimmed_reads/$b.1.clipped.fastq" > "$b.1.fasta"
if [[ -e "../02.trimmed_reads/$b.2.clipped.fastq" ]] ; then
  awk -f "$FQ2A" < "../02.trimmed_reads/$b.2.clipped.fastq" > "$b.2.fasta"
  FastA.interpose.pl "$b.CoupledReads.fa" "$b".[12].fasta
  gzip -9 -f "$b.2.fasta"
  gzip -9 -f "$b.1.fasta"
  awk -f "$FQ2A" < "../02.trimmed_reads/$b".[12].clipped.single.fastq \
    > "$b.SingleReads.fa"
  gzip -9 -f "$b.SingleReads.fa"
else
   mv "$b.1.fasta" "$b.SingleReads.fa"
fi

# Compress input at 01.raw_reads and 02.trimmed_reads
for sis in 1 2 ; do
  [[ -e "../01.raw_reads/$b.$sis.fastq" ]] \
    && gzip -9 -f "../01.raw_reads/$b.$sis.fastq"
  [[ -e "../02.trimmed_reads/$b.$sis.clipped.fastq" ]] \
    && gzip -9 -f "../02.trimmed_reads/$b.$sis.clipped.fastq"
  [[ -e "../02.trimmed_reads/$b.$sis.clipped.single.fastq" ]] \
    && gzip -9 -f "../02.trimmed_reads/$b.$sis.clipped.single.fastq"
done

# Finalize
miga date > "$DATASET.done"
miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT" -f
