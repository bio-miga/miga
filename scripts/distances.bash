#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/09.distances"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.start"

# Check type of dataset
NOMULTI=$($MIGA/bin/list_datasets -P "$PROJECT" -D "$DATASET" --no-multi | wc -l | awk '{print $1}')
ESS="../07.annotation/01.function/01.essential"
if [[ "$NOMULTI" -eq "1" ]] ; then
   # Traverse "nearly-half" of the ref-datasets using first-come-first-served
   for i in $($MIGA/bin/list_datasets -P "$PROJECT" --ref --no-multi) ; do
      # Check if the i-th dataset is ready
      [[ -s $ESS/$i.done && -s $ESS/$i.json ]] || continue
      # Check if this is done (e.g., in a previous failed iteration)
      AAI=$( echo "select aai from aai where seq1='$DATASET' and seq2='$i';" | sqlite3 02.aai/$DATASET.db 2>/dev/null || echo "" )
      # Try the other direction
      if [[ "$AAI" == "" && -s 02.aai/$i.db ]] ; then
	 AAI=$( echo "select aai from aai where seq2='$DATASET' and seq1='$i';" | sqlite3 02.aai/$DATASET.db 2>/dev/null || echo "" )
      fi
      # Try with hAAI
      if [[ "$AAI" == "" || "$AAI" -eq 0 ]] ; then
	 HAAI=$( aai.rb -1 $ESS/$DATASET.ess.faa -2 $ESS/$i.ess.faa -t $CORES -a -n 10 -S 01.haai/$DATASET.db || echo "" )
	 if [[ "$HAAI" != "" && $(perl -MPOSIX -e "print floor $HAAI") -lt 90 ]] ; then
	    AAI=$(perl -e "printf '%f', 100-exp(2.435076 + 0.4275193*log(100-$HAAI))")
	    echo "create table if not exists aai(seq1 varchar(256),seq2 varchar(256),aai float,sd float,n int,omega int);" | sqlite3 02.aai/$DATASET.db
	    echo "insert into aai values('$DATASET','$i','$AAI',0,0,0);" | sqlite3 02.aai/$DATASET.db
	 fi
      fi
      # Try with complete AAI
      if [[ "$AAI" == "" || "$AAI" -eq 0 ]] ; then
	 AAI=$( aai.rb -1 ../06.cds/$DATASET.faa -2 ../06.cds/$i.faa -t $CORES -a -S 02.aai/$DATASET.db )
      fi
      # Check if ANI is meaningful
      if [[ -e "../05.assembly/$DATASET.LargeContigs.fna" && -e "../05.assembly/$i.LargeContigs.fna" && $(perl -MPOSIX -e "print ceil $AAI") -gt 90 ]] ; then
	 ANI=$( ani.rb -1 ../05.assembly/$DATASET.LargeContigs.fna -2 ../05.assembly/$i.LargeContigs.fna -t $CORES -S 03.ani/$DATASET.db -a || echo "" )
      fi
   done
fi

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.done"
$MIGA/bin/add_result -P "$PROJECT" -D "$DATASET" -r distances

