#!/bin/bash
# Available variables: $PROJECT, $DATASET, $RUNTYPE
source "$(dirname "$0")/miga.bash" # Available variables: $CORES, $MIGA
cd "$PROJECT/data/03.read_quality"

b=$DATASET

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.start"

# FastQC
[[ -d "$b.fastqc" ]] || mkdir "$b.fastqc"
fastqc ../02.trimmed_reads/$b.[12].clipped.fastq -o $b.fastqc ;

# SolexaQA++
[[ -d "$b.solexaqa" ]] || mkdir "$b.solexaqa"
exists ../02.trimmed_reads/$b.[12].*.pdf && mv ../02.trimmed_reads/$b.[12].*.pdf "$b.solexaqa/"

# Clean 02.trimmed_reads
[[ -e "../02.trimmed_reads/$b.1.fastq_trimmed.segments" ]] && rm ../02.trimmed_reads/$b.[12].fastq_trimmed.segments
[[ -e "../02.trimmed_reads/$b.1.fastq.trimmed.paired" ]] && rm ../02.trimmed_reads/$b.[12].fastq.trimmed.paired
[[ -e "../02.trimmed_reads/$b.1.fastq.trimmed.single" ]] && rm ../02.trimmed_reads/$b.[12].fastq.trimmed.single
[[ -e "../02.trimmed_reads/$b.1.fastq.trimmed" ]] && rm ../02.trimmed_reads/$b.[12].fastq.trimmed
[[ -e "../02.trimmed_reads/$b.1.fastq" ]] && rm ../02.trimmed_reads/$b.[12].fastq

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.done"
"$MIGA/bin/add_result" -P "$PROJECT" -D "$DATASET" -r read_quality

