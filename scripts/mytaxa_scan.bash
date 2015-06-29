#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
source "$MIGA/scripts/miga.bash" || exit 1
DIR="$PROJECT/data/07.annotation/03.qa/02.mytaxa_scan"
[[ -d "$DIR" ]] || mkdir -p "$DIR"
cd "$DIR"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.start"
MT=$(dirname -- $(which MyTaxa))

# Check type of dataset
NOMULTI=$($MIGA/bin/list_datasets -P "$PROJECT" -D "$DATASET" --no-multi | wc -l | awk '{print $1}')
if [[ "$NOMULTI" -eq "1" ]] ; then
   # Check requirements
   if [[ ! -e "$MT/AllGenomes.faa.pal" ]] ; then
      echo "Cannot locate the database: $MT/AllGenomes.faa.pal: no such file or directory" >&2
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
   diamond blastp -q "../../../06.cds/$DATASET.faa" -d "$MT/AllGenomes.faa" -k 5 -p "$CORES" --min-score 60 -a "$DATASET.daa"
   diamond view -a "$DATASET.daa" -o "$DATASET.blast"

   # Prepare MyTaxa input, execute MyTaxa, and generate profiles
   perl "$MT/utils/infile_convert.pl" -f no "LOREM_IPSUM" "$DATASET.blast" | sort -k 13 > "$DATASET.mytaxain"
   "$MT/MyTaxa" "$DATASET.mytaxain" "$DATASET.mytaxa" "0.5"
   ruby "$MIGA/utils/mytaxa_scan.rb" "../../../06.cds/$DATASET.faa" "$DATASET.wintax"
   echo "load('$MIGA/utils/mytaxa_scan.R'); pdf('$DATASET.pdf', 12, 7); mytaxa.scan('$DATASET.wintax'); dev.off();" | R --vanilla

   # Clean
   rm "$DATASET.daa"
fi

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.done"
$MIGA/bin/add_result -P "$PROJECT" -D "$DATASET" -r mytaxa_scan

