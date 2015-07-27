#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/09.distances"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.start"
TMPDIR=$(mktemp -d /tmp/MiGA.XXXXXXXXXXXX)

function checkpoint_n {
   if [[ $N -eq 10 ]] ; then
      for t in 01.haai 02.aai 03.ani ; do
         [[ -s $TMPDIR/$t.db ]] && cp $TMPDIR/$t.db $t/$DATASET.db
      done
      N=0
   fi
   let N=$N+1
}

# Check type of dataset
NOMULTI=$($MIGA/bin/list_datasets -P "$PROJECT" -D "$DATASET" --no-multi | wc -l | awk '{print $1}')
ESS="../07.annotation/01.function/01.essential"
if [[ "$NOMULTI" -eq "1" ]] ; then
   N=10
   checkpoint_n
   echo "create table if not exists aai(seq1 varchar(256),seq2 varchar(256),aai float,sd float,n int,omega int);" | sqlite3 $TMPDIR/02.aai.db
   # Traverse "nearly-half" of the ref-datasets using first-come-first-served
   for i in $($MIGA/bin/list_datasets -P "$PROJECT" --ref --no-multi) ; do
      echo "=[ $i ]"
      date "+%Y-%m-%d %H:%M:%S %z"
      # Check if the i-th dataset is ready
      [[ -s $ESS/$i.done && -s $ESS/$i.json ]] || continue
      # Check if this is done (e.g., in a previous failed iteration)
      AAI=$( echo "select aai from aai where seq1='$DATASET' and seq2='$i';" | sqlite3 $TMPDIR/02.aai.db || echo "" )
      # Try the other direction
      if [[ "$AAI" == "" && -s 02.aai/$i.db ]] ; then
	 cp "02.aai/$i.db" "$TMPDIR/$i.db"
	 AAI=$( echo "select aai from aai where seq2='$DATASET' and seq1='$i';" | sqlite3 "$TMPDIR/$i.db" || echo "" )
	 rm "$TMPDIR/$i.db"
      fi
      # Try with hAAI
      if [[ "$AAI" == "" ]] ; then
	 [[ -e "$TMPDIR/$DATASET.ess.fa" ]] || cp $ESS/$DATASET.ess.fa $TMPDIR/$DATASET.ess.fa
	 HAAI=$( aai.rb -1 $TMPDIR/$DATASET.ess.faa -2 $ESS/$i.ess.faa -t $CORES -a -n 10 -S $TMPDIR/01.haai.db --name1 $DATASET --name2 $i || echo "" )
	 if [[ "$HAAI" != "" && $(perl -MPOSIX -e "print floor $HAAI") -lt 90 ]] ; then
	    AAI=$(perl -e "printf '%f', 100-exp(2.435076 + 0.4275193*log(100-$HAAI))")
	    echo "insert into aai values('$DATASET','$i','$AAI',0,0,0);" | sqlite3 $TMPDIR/02.aai.db
	 fi
      fi
      # Try with complete AAI
      if [[ "$AAI" == "" ]] ; then
	 [[ -e "$TMPDIR/$DATASET.faa" ]] || cp ../06.cds/$DATASET.faa $TMPDIR/$DATASET.faa
	 AAI=$( aai.rb -1 $TMPDIR/$DATASET.faa -2 ../06.cds/$i.faa -t $CORES -a -S $TMPDIR/02.aai.db --name1 $DATASET --name2 $i || echo "" )
      fi
      date "+%Y-%m-%d %H:%M:%S %z"
      # Check if ANI is meaningful
      if [[ -e "../05.assembly/$DATASET.LargeContigs.fna" && -e "../05.assembly/$i.LargeContigs.fna" && $(perl -MPOSIX -e "print ceil $AAI") -gt 90 ]] ; then
	 # Check if this is done (e.g., in a previous failed iteration)
	 ANI=$( echo "select ani from ani where seq1='$DATASET' and seq2='$i';" | sqlite3 $TMPDIR/03.ani.db || echo "" )
	 # Try the other direction
	 if [[ "$ANI" == "" && -s 03.ani/$i.db ]] ; then
	    cp "03.ani/$i.db" "$TMPDIR/$i.db"
	    ANI=$( echo "select ani from ani where seq2='$DATASET' and seq1='$i';" | sqlite3 "$TMPDIR/$i.db" || echo "" )
	    rm "$TMPDIR/$i.db"
	 fi
	 # Calculate it
	 if [[ "$ANI" == "" ]] ; then
	    [[ -e "$TMPDIR/$DATASET.LargeContigs.fna" ]] || cp ../05.assembly/$DATASET.LargeContigs.fna $TMPDIR/$DATASET.LargeContigs.fna
	    ANI=$( ani.rb -1 $TMPDIR/$DATASET.LargeContigs.fna -2 ../05.assembly/$i.LargeContigs.fna -t $CORES -S $TMPDIR/03.ani.db -a --name1 $DATASET --name2 $i || echo "" )
	 fi
      fi
      echo "$AAI;$ANI"
      checkpoint_n
   done
   N=10
   checkpoint_n
fi

rm -R $TMPDIR

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.done"
$MIGA/bin/add_result -P "$PROJECT" -D "$DATASET" -r distances

