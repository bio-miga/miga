#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/04.trimmed_fasta"

b=$DATASET

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.start"

# FastQ -> FastA
cat ../02.trimmed_reads/$b.1.clipped.fastq | FastQ.toFastA.awk > $b.1.fasta
if [[ -e ../02.trimmed_reads/$b.2.clipped.fastq ]] ; then
   cat ../02.trimmed_reads/$b.2.clipped.fastq | FastQ.toFastA.awk > $b.2.fasta
   FastA.interpose.pl $b.CoupledReads.fa $b.[12].fasta
   gzip $b.2.fasta
   gzip $b.1.fasta
   cat ../02.trimmed_reads/$b.[12].clipped.single.fastq | FastQ.toFastA.awk > $b.SingleReads.fasta
   gzip $b.SingleReads.fasta
else
   mv $b.1.fasta $b.SingleReads.fa
fi

# Compress input at 01.raw_reads and 02.trimmed_reads
for sis in 1 2 ; do
   [[ -e "../01.raw_reads/$b.$sis.fastq" ]] && gzip "../01.raw_reads/$b.$sis.fastq"
   [[ -e "../02.trimmed_reads/$b.$sis.clipped.fastq" ]] && gzip "../02.trimmed_reads/$b.$sis.clipped.fastq"
done

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.done"
$MIGA/bin/add_result -P "$PROJECT" -D "$DATASET" -r trimmed_fasta

