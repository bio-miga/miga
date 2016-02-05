#!/bin/bash
# Available variables: $PROJECT, $DATASET, $RUNTYPE, $MIGA, $CORES, $TMPDIR,
# 			$NOMULTI, $REF

function checkpoint_n {
   if [[ $N -eq 10 ]] ; then
      for t in 01.haai 02.aai 03.ani ; do
         if [[ -s $TMPDIR/$t.db ]] ; then
	    tab="aai"
	    [[ "$t" == "03.ani" ]] && tab="ani"
	    echo "select count(*) from $tab;" \
	       | sqlite3 $TMPDIR/$t.db\
	       || exit 1
	    cp $TMPDIR/$t.db $t/$DATASET.db
	 fi
      done
      N=0
   fi
   let N=$N+1
}

ESS="../07.annotation/01.function/01.essential"

# Initialize temporals
for t in 01.haai 02.aai 03.ani ; do
   [[ -s $t/$DATASET.db ]] && cp $t/$DATASET.db $TMPDIR/$t.db
done
echo "create table if not exists aai(seq1 varchar(256), seq2 varchar(256)," \
   "aai float, sd float, n int, omega int);" | sqlite3 $TMPDIR/02.aai.db
N=1

# Traverse "nearly-half" of the ref-datasets using first-come-first-served
for i in $(miga list_datasets -P "$PROJECT" --ref --no-multi) ; do
   echo "=[ $i ]"
   date "+%Y-%m-%d %H:%M:%S %z"
   HAAI=""; AAI=""; ANI="";
   # Check if the i-th dataset is ready
   [[ -s $ESS/$i.done && -s $ESS/$i.json ]] || continue
   # Check if this is done (e.g., in a previous failed iteration)
   AAI=$(echo "select aai from aai where seq1='$DATASET' and seq2='$i';" \
      | sqlite3 $TMPDIR/02.aai.db || echo "")
   # Try the other direction
   if [[ "$AAI" == "" && -s 02.aai/$i.db ]] ; then
      cp "02.aai/$i.db" "$TMPDIR/$i.db"
      AAI=$(echo "select aai from aai where seq2='$DATASET' and seq1='$i';" \
	 | sqlite3 "$TMPDIR/$i.db" || echo "")
      rm "$TMPDIR/$i.db"
   fi
   # Try with hAAI
   if [[ "$AAI" == "" ]] ; then
      [[ -e "$TMPDIR/$DATASET.ess.faa" ]] \
	 || cp $ESS/$DATASET.ess.faa $TMPDIR/$DATASET.ess.faa
      HAAI=$(aai.rb -1 $TMPDIR/$DATASET.ess.faa -2 $ESS/$i.ess.faa \
	 -t $CORES -a -n 10 -S $TMPDIR/01.haai.db --name1 $DATASET \
	 --name2 $i --lookup-first --no-save-rbm || echo "")
      if [[ "$HAAI" != "" \
	    && $(perl -MPOSIX -e "print floor $HAAI") -lt 90 ]] ; then
	 AAI=$(perl -e \
	    "printf '%f', 100-exp(2.435076 + 0.4275193*log(100-$HAAI))")
	 echo "insert into aai values('$DATASET','$i','$AAI',0,0,0);" \
	    | sqlite3 $TMPDIR/02.aai.db
      fi
   fi
   # Try with complete AAI
   if [[ "$AAI" == "" ]] ; then
      [[ -e "$TMPDIR/$DATASET.faa" ]] \
	 || cp ../06.cds/$DATASET.faa $TMPDIR/$DATASET.faa
      AAI=$(aai.rb -1 $TMPDIR/$DATASET.faa -2 ../06.cds/$i.faa -t $CORES -a \
	 -S $TMPDIR/02.aai.db --name1 $DATASET --name2 $i --lookup-first \
	 || echo "")
   fi
   date "+%Y-%m-%d %H:%M:%S %z"
   # Check if ANI is meaningful
   if [[ -e "../05.assembly/$DATASET.LargeContigs.fna" \
	 && -e "../05.assembly/$i.LargeContigs.fna" \
	 && $(perl -MPOSIX -e "print ceil $AAI") -gt 90 ]] ; then
      # Check if this is done (e.g., in a previous failed iteration)
      ANI=$(echo "select ani from ani where seq1='$DATASET' and seq2='$i';" \
	 | sqlite3 $TMPDIR/03.ani.db || echo "")
      # Try the other direction
      if [[ "$ANI" == "" && -s 03.ani/$i.db ]] ; then
	 cp "03.ani/$i.db" "$TMPDIR/$i.db"
	 ANI=$(echo "select ani from ani" \
	    "where seq2='$DATASET' and seq1='$i';" \
	    | sqlite3 "$TMPDIR/$i.db" || echo "")
	 rm "$TMPDIR/$i.db"
      fi
      # Calculate it
      if [[ "$ANI" == "" ]] ; then
	 [[ -e "$TMPDIR/$DATASET.LargeContigs.fna" ]] \
	    || cp ../05.assembly/$DATASET.LargeContigs.fna \
	       $TMPDIR/$DATASET.LargeContigs.fna
	 ANI=$(ani.rb -1 $TMPDIR/$DATASET.LargeContigs.fna \
	    -2 ../05.assembly/$i.LargeContigs.fna -t $CORES \
	    -S $TMPDIR/03.ani.db -a --name1 $DATASET --name2 $i \
	    --no-save-regions --no-save-rbm --lookup-first \
	    || echo "")
      fi
   fi
   echo "$AAI;$ANI"
   checkpoint_n
done
N=10
checkpoint_n

