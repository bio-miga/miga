#!/bin/bash
# Available variables: $PROJECT, $DATASET, $CORES
source "$(dirname "$0")/miga.bash" # Available variables: $MIGA
cd "$PROJECT/data/04.trimmed_fasta"

b=$DATASET

# FastQ -> FastA
cat ../02.trimmed_reads/$b.1.clipped.fastq | paste - - - - | awk 'BEGIN{FS="\\t"}{print ">"substr($1,2)"\\n"$2}' > $b.1.fasta
if [[ -e ../02.trimmed_reads/$b.2.clipped.fastq ]] ; then
   cat ../02.trimmed_reads/$b.2.clipped.fastq | paste - - - - | awk 'BEGIN{FS="\\t"}{print ">"substr($1,2)"\\n"$2}' > $b.2.fasta
   FastA.interpose.pl $b.CoupledReads.fa $b.[12].fasta
   gzip $b.2.fasta
   gzip $b.1.fasta
else
   mv $b.1.fasta $b.SingleReads.fa
fi

# Compress input at 01.raw_reads
for i in ../01.raw_reads/$b.[12].fastq ; do
   gzip $i
done

# Finalize
date > "$DATASET.done"

