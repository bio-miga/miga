#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
source "$MIGA/scripts/miga.bash" || exit 1
DIR="$PROJECT/data/07.annotation/01.function/02.rrna"
[[ -d "$DIR" ]] || mkdir -p "$DIR"
cd "$DIR"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.start"

# Run barrnap
fa="../../../05.assembly/$DATASET.LargeContigs.fna"
barrnap --quiet --threads $CORES $fa | grep "^##gff\\|;product=16S " \
   > $DATASET.ssu.gff 

# Extract
bedtools getfasta -s "-fi" $fa -bed $DATASET.ssu.gff -fo $DATASET.ssu.all.fa 
FastA.length.pl $DATASET.ssu.all.fa | sort -nr -k 2 | head -n 1 \
   | cut -f 1 > $DATASET.ssu.fa.id 
FastA.filter.pl $DATASET.ssu.fa.id $DATASET.ssu.all.fa > $DATASET.ssu.fa 
rm $DATASET.ssu.fa.id 

# Gzip
gzip -9 -f "$DATASET.ssu.gff"
gzip -9 -f "$DATASET.ssu.all.fa"

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.done"
$MIGA/bin/add_result -P "$PROJECT" -D "$DATASET" -r ssu

