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
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.start"

# Gunzip (if necessary)
for sis in 1 2 ; do
   [[ -e "../02.trimmed_reads/$b.$sis.clipped.fastq.gz" \
      && ! -e "../02.trimmed_reads/$b.$sis.clipped.fastq" ]] \
      && gunzip "../02.trimmed_reads/$b.$sis.clipped.fastq.gz"
done

# FastQ -> FastA
cat ../02.trimmed_reads/$b.1.clipped.fastq | FastQ.toFastA.awk > $b.1.fasta
if [[ -e ../02.trimmed_reads/$b.2.clipped.fastq ]] ; then
   cat ../02.trimmed_reads/$b.2.clipped.fastq | FastQ.toFastA.awk > $b.2.fasta
   FastA.interpose.pl $b.CoupledReads.fa $b.[12].fasta
   gzip -9 -f $b.2.fasta
   gzip -9 -f $b.1.fasta
   cat ../02.trimmed_reads/$b.[12].clipped.single.fastq | FastQ.toFastA.awk \
      > $b.SingleReads.fa
   gzip -9 -f $b.SingleReads.fa
else
   mv $b.1.fasta $b.SingleReads.fa
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
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.done"
miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT"
