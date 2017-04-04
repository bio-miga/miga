#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES, $DATASET
set -e
SCRIPT="ssu"
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
source "$MIGA/scripts/miga.bash" || exit 1
DIR="$PROJECT/data/07.annotation/01.function/02.ssu"
[[ -d "$DIR" ]] || mkdir -p "$DIR"
cd "$DIR"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.start"

fa="../../../05.assembly/$DATASET.LargeContigs.fna"
if [[ -s $fa ]] ; then
   # Run barrnap
   barrnap --quiet --threads $CORES $fa | grep "^##gff\\|;product=16S " \
      > $DATASET.ssu.gff 

   # Extract
   bedtools getfasta -s "-fi" $fa -bed $DATASET.ssu.gff -fo $DATASET.ssu.all.fa 
   FastA.length.pl $DATASET.ssu.all.fa | sort -nr -k 2 | head -n 1 \
      | cut -f 1 > $DATASET.ssu.fa.id 
   FastA.filter.pl $DATASET.ssu.fa.id $DATASET.ssu.all.fa > $DATASET.ssu.fa 
   rm $DATASET.ssu.fa.id 
   [[ -e "$fa.fai" ]] && rm "$fa.fai"

   # Gzip
   gzip -9 -f "$DATASET.ssu.gff"
   gzip -9 -f "$DATASET.ssu.all.fa"
fi

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.done"
miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT"
