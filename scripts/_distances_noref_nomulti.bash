#!/bin/bash
# Available variables: $PROJECT, $DATASET, $RUNTYPE, $MIGA, $CORES, $TMPDIR,
# 			$NOMULTI, $REF

# Deal with previous runs (if any)
exists $DATASET.a[an]i.db && cp $DATASET.a[an]i.db $TMPDIR
exists $DATASET.a[an]i.9[05] && rm $DATASET.a[an]i.9[05]
N=0
function checkpoint_n {
   let N=$N+1
   if [[ $N -ge 10 ]] ; then
      for metric in aai ani ; do
	 if [[ -s $TMPDIR/$DATASET.$metric.db ]] ; then
	    echo "select count(*) from $metric;" \
	       | sqlite3 $TMPDIR/$DATASET.$metric.db \
	       || exit 1
	    cp $TMPDIR/$DATASET.$metric.db .
	 fi
      done
      N=0
   fi
}

# Find 95%ANI clade(s) with AAI <= 90% / ANI <= 95%
REFGENOMES=$(cat ../10.clades/01.find/miga-project.ani95-clades \
   | tail -n +2 | cut -d , -f 1)
for i in $REFGENOMES ; do
   AAI=$(aai.rb -1 ../06.cds/$DATASET.faa \
      -2 ../06.cds/$i.faa -t $CORES -a --lookup-first \
      -S $TMPDIR/$DATASET.aai.db --name1 $DATASET --name2 $i || echo "")
   checkpoint_n
   if [[ $(perl -MPOSIX -e "print ceil $AAI") -ge 90 ]] ; then
      echo $i >> $DATASET.aai90
      [[ -e "../05.assembly/$DATASET.LargeContigs.fna" ]] || continue
      [[ -e "../05.assembly/$i.LargeContigs.fna" ]] || continue
      ANI=$(ani.rb -1 ../05.assembly/$DATASET.LargeContigs.fna \
	 -2 ../05.assembly/$i.LargeContigs.fna -t $CORES -a --lookup-first \
	 -S $TMPDIR/$DATASET.ani.db --name1 $DATASET --name2 $i || echo "")
      checkpoint_n
      if [[ $(perl -MPOSIX -e "print ceil $ANI") -ge 95 ]] ; then
	 echo $i >> $DATASET.ani95
      fi
   fi
done

# Classify in-clade (if project type is clade)
CLADES="../10.clades/02.ani"
CLASSIF="."
MAX_ANI=0
ANI_MED=""
[[ -e "$DATASET.medoids" ]] && rm "$DATASET.medoids"
while [[ -e "$CLADES/$CLASSIF/miga-project.1.medoids" ]] ; do
   for i in $(cat "$CLADES/$CLASSIF/miga-project.1.medoids") ; do
      ANI=$(ani.rb -1 ../05.assembly/$DATASET.LargeContigs.fna \
	 -2 ../05.assembly/$i.LargeContigs.fna -t $CORES -a --lookup-first \
	 -S $TMPDIR/$DATASET.ani.db --name1 $DATASET --name2 $i || echo "")
      checkpoint_n
      if [[ $(perl -e "print 1 if $ANI > $MAX_ANI") == "1" ]] ; then
         MAX_ANI=$ANI
	 ANI_MED=$i
      fi
   done
   echo $i >> "$DATASET.medoids"
   CLASSIF="$CLASSIF/miga-project.1.subcl-$i"
done
echo $CLASSIF > "$DATASET.class"

# Calculate all the ANIs against the lowest subclade (if classified in-clade)
if [[ "$CLASSIF" != "." ]] ; then
   if [[ -s "$CLADES/$CLASSIF/miga-project.all" ]] ; then
      for i in $(cat "$CLADES/$CLASSIF/miga-project.all") ; do
	 ANI=$(ani.rb -1 ../05.assembly/$DATASET.LargeContigs.fna \
	    -2 ../05.assembly/$i.LargeContigs.fna -t $CORES -a --lookup-first \
	    -S $TMPDIR/$DATASET.ani.db --name1 $DATASET --name2 $i || echo "")
	 checkpoint_n
      done
   fi
fi

# Finalize
mv $TMPDIR/$DATASET.aai.db 02.aai/$DATASET.db
mv $TMPDIR/$DATASET.ani.db 03.ani/$DATASET.db

