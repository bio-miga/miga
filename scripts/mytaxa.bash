#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
source "$MIGA/scripts/miga.bash" || exit 1
DIR="$PROJECT/data/07.annotation/02.taxonomy/01.mytaxa"
[[ -d "$DIR" ]] || mkdir -p "$DIR"
cd "$DIR"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.start"
MT=$(dirname -- $(which MyTaxa))

# Check type of dataset
MULTI=$($MIGA/bin/list_datasets -P "$PROJECT" -D "$DATASET" --multi | wc -l | awk '{print $1}')
if [[ "$MULTI" -eq "1" ]] ; then
   # Check requirements
   if [[ ! -e "$MT/AllGenomes.faa.dmnd" ]] ; then
      echo "Cannot locate the database: $MT/AllGenomes.faa.dmnd: no such file or directory" >&2
      exit 1
   fi
   if [[ ! -d "$MT/db" ]] ; then
      echo "Cannot locate the MyTaxa index: $MT/db: no such file or directory" >&2
      exit 1
   fi
   if [[ ! -d "$MT/utils" ]] ; then
      echo "Cannot locate the MyTaxa utilities: $MT/utils: no such file or directory" >&2
      exit 1
   fi
   
   # Execute search
   #blastp -query "../../../06.cds/$DATASET.faa" -db "$MT/AllGenomes.faa" -out "$DATASET.blast" -evalue "1e-10" -outfmt 6 -max_target_seqs 5 -num_threads "$CORES"
   diamond blastp -q "../../../06.cds/$DATASET.faa" -d "$MT/AllGenomes.faa" -a "$DATASET.daa" -k 5 -p "$CORES" --min-score 60
   diamond view -a "$DATASET.daa" -o "$DATASET.blast"

   # Prepare MyTaxa input, execute MyTaxa, and generate profiles
   [[ -e "../../../06.cds/$DATASET.gff2.gz" ]] && [[ ! -e "../../../06.cds/$DATASET.gff2" ]] && gunzip "../../../06.cds/$DATASET.gff2.gz"
   [[ -e "../../../06.cds/$DATASET.gff3.gz" ]] && [[ ! -e "../../../06.cds/$DATASET.gff3" ]] && gunzip "../../../06.cds/$DATASET.gff3.gz"
   if [[ -e "../../../06.cds/$DATASET.gff2" ]] ; then
      # GFF2
      perl "$MT/utils/infile_convert.pl" -f gff2 "../../../06.cds/$DATASET.gff2" "$DATASET.blast" | sort -k 13 > "$DATASET.mytaxain"
      "$MT/MyTaxa" "$DATASET.mytaxain" "$DATASET.mytaxa" "0.5"
      perl "$MT/utils/MyTaxa.distribution.pl" -m "$DATASET.mytaxa" -g "../../../06.cds/$DATASET.gff2" -f gff2 -I "$DATASET.mytaxa.innominate" -G "$DATASET.mytaxa.genes" -K "$DATASET.mytaxa.krona" -u
   elif [[ -e "../../../06.cds/$DATASET.gff3" ]] ; then
      # GFF3
      perl "$MT/utils/infile_convert.pl" -f gff3 "../../../06.cds/$DATASET.gff3" "$DATASET.blast" | sort -k 13 > "$DATASET.mytaxain"
      "$MT/MyTaxa" "$DATASET.mytaxain" "$DATASET.mytaxa" "0.5"
      perl "$MT/utils/MyTaxa.distribution.pl" -m "$DATASET.mytaxa" -g "../../../06.cds/$DATASET.gff3" -f gff3 -I "$DATASET.mytaxa.innominate" -G "$DATASET.mytaxa.genes" -K "$DATASET.mytaxa.krona" -u
   else
      # No GFF
      perl "$MT/utils/infile_convert.pl" -f no "LOREM_IPSUM" "$DATASET.blast" | sort -k 13 > "$DATASET.mytaxain"
      "$MT/MyTaxa" "$DATASET.mytaxain" "$DATASET.mytaxa" "0.5"
      perl "$MT/utils/MyTaxa.distribution.pl" -m "$DATASET.mytaxa" -I "$DATASET.mytaxa.innominate" -G "$DATASET.mytaxa.genes" -K "$DATASET.mytaxa.krona" -u
   fi

   # Execute Krona
   ktImportText -o "$DATASET.html" -n biota "$DATASET.mytaxa.krona,$DATASET"

   # Gzip and cleanup
   [[ -e "../../../06.cds/$DATASET.gff2" ]] && gzip -9 -f "../../../06.cds/$DATASET.gff2"
   [[ -e "../../../06.cds/$DATASET.gff3" ]] && gzip -9 -f "../../../06.cds/$DATASET.gff3"
   gzip -9 -f "$DATASET.mytaxain"
   gzip -9 -f "$DATASET.blast"
   rm "$DATASET.daa"
fi

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.done"
$MIGA/bin/add_result -P "$PROJECT" -D "$DATASET" -r mytaxa

