#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES, $DATASET
set -e
SCRIPT="read_quality"
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
# shellcheck source=scripts/miga.bash
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/03.read_quality"

b=$DATASET

# Initialize
miga date > "$DATASET.start"

# FastQC
[[ -d "$b.fastqc" ]] || mkdir "$b.fastqc"
fastqc "../02.trimmed_reads/$b".[12].clipped.fastq -o "$b.fastqc"

# SolexaQA++
[[ -d "$b.solexaqa" ]] || mkdir "$b.solexaqa"
exists "../02.trimmed_reads/$b".[12].*.pdf \
  && mv "../02.trimmed_reads/$b".[12].*.pdf "$b.solexaqa/"

# Clean 02.trimmed_reads
rm -f "../02.trimmed_reads/$b".[12].fastq_trimmed.segments
rm -f "../02.trimmed_reads/$b".[12].fastq.trimmed.paired
rm -f "../02.trimmed_reads/$b".[12].fastq.trimmed.single
rm -f "../02.trimmed_reads/$b".[12].fastq.trimmed
rm -f "../02.trimmed_reads/$b".[12].fastq

# Finalize
miga date > "$DATASET.done"
miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT"
