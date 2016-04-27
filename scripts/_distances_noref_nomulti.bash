#!/bin/bash
# Available variables: $PROJECT, $DATASET, $RUNTYPE, $MIGA, $CORES, $TMPDIR,
#                      $NOMULTI, $REF

set -e

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

if [[ $(miga project_info -P "$PROJECT" -m type) != "clade" ]] ; then
  # Classify aai-clade (if project type is not clade)
  CLADES="../10.clades/01.find"
  CLASSIF="."
  MAX_AAI=0
  AAI_MED=""
  AAI_CLS=""
  [[ -e "$DATASET.aai-medoids.tsv" ]] && rm "$DATASET.aai-medoids.tsv"
  while [[ -e "$CLADES/$CLASSIF/miga-project.1.medoids" ]] ; do
    i_n=0
    for i in $(cat "$CLADES/$CLASSIF/miga-project.1.medoids") ; do
      let i_n=$i_n+1
      AAI=$(aai.rb -1 ../06.cds/$DATASET.faa \
        -2 ../06.cds/$i.faa -t $CORES -a --lookup-first \
        -S $TMPDIR/$DATASET.aai.db --name1 $DATASET --name2 $i || echo "0")
      checkpoint_n
      if [[ $(perl -e "print 1 if $AAI >= $MAX_AAI") == "1" ]] ; then
        MAX_AAI=$AAI
        AAI_MED=$i
        AAI_CLS=$i_n
      fi
    done
    CLASSIF="$CLASSIF/miga-project.1.subcl-$AAI_CLS"
    echo "$AAI_CLS      $AAI_MED	$MAX_AAI	$CLASSIF" \
      >> "$DATASET.aai-medoids.tsv"
  done
else
  # Classify ani-clade (if project type is clade)
  CLADES="../10.clades/02.ani"
  CLASSIF="."
  MAX_ANI=0
  ANI_MED=""
  ANI_CLS=""
  [[ -e "$DATASET.ani-medoids.tsv" ]] && rm "$DATASET.ani-medoids.tsv"
  while [[ -e "$CLADES/$CLASSIF/miga-project.1.medoids" ]] ; do
    i_n=0
    for i in $(cat "$CLADES/$CLASSIF/miga-project.1.medoids") ; do
      let i_n=$i_n+1
      ANI=$(ani.rb -1 ../05.assembly/$DATASET.LargeContigs.fna \
        -2 ../05.assembly/$i.LargeContigs.fna -t $CORES -a \
        --no-save-regions --no-save-rbm --lookup-first \
        -S $TMPDIR/$DATASET.ani.db --name1 $DATASET --name2 $i || echo "0")
      checkpoint_n
      if [[ $(perl -e "print 1 if $ANI >= $MAX_ANI") == "1" ]] ; then
        MAX_ANI=$ANI
        ANI_MED=$i
        AAI_CLS=$i_n
      fi
    done
    CLASSIF="$CLASSIF/miga-project.1.subcl-$ANI_CLS"
    echo "$ANI_CLS      $ANI_MED	$MAX_ANI	$CLASSIF" \
      >> "$DATASET.ani-medoids.tsv"
  done

  # Calculate all the ANIs against the lowest subclade (if classified in-clade)
  if [[ "$CLASSIF" != "." ]] ; then
    if [[ -s "$CLADES/$CLASSIF/miga-project.all" ]] ; then
      for i in $(cat "$CLADES/$CLASSIF/miga-project.all") ; do
        ani.rb -1 ../05.assembly/$DATASET.LargeContigs.fna \
          -2 ../05.assembly/$i.LargeContigs.fna -t $CORES -q \
          --no-save-regions --no-save-rbm --lookup-first \
          -S $TMPDIR/$DATASET.ani.db --name1 $DATASET --name2 $i \
          > /dev/null
        checkpoint_n
      done
    fi
  fi
fi

#Finalize
N=11
checkpoint_n
