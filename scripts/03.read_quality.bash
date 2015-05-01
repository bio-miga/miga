#!/bin/bash
# Available variables: $PROJECT, $DATASET, $CORES
source "$(dirname "$0")/miga.bash" # Available variables: $MIGA
cd "$PROJECT/data/03.read_quality"

b=$DATASET

# FastQC
[[ -d $b.fastqc ]] || mkdir $b.fastqc
fastqc ../02.trimmed_reads/$b.[12].clipped.fastq -o $b.fastqc ;

# SolexaQA++
[[ -d $b.solexaqa ]] || mkdir $b.solexaqa
SolexaQA++ analysis ../01.raw_reads/$b.[12].fastq -h 20 -d $b.solexaqa -v -m
rm $b.solexaqa/*.segments
mv ../02.trimmed_reads/$b.[12].fastq_trimmed.segments* $b.solexaqa/
mv ../02.trimmed_reads/$b.[12].fastq.trimmed.summary.txt* $b.solexaqa/

# Clean 02.trimmed_reads
rm ../02.trimmed_reads/$b.[12].fastq.trimmed.discard
rm ../02.trimmed_reads/$b.[12].fastq.trimmed
rm ../02.trimmed_reads/$b.[12].fastq

# Finalize
date > "$DATASET.done"

