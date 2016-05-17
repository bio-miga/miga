#!/bin/bash
# Available variables: $PROJECT, $DATASET, $RUNTYPE, $MIGA, $CORES, $TMPDIR,
#                      $NOMULTI, $REF

set -e

# Deal with previous runs (if any)
exists $DATASET.haai.db && cp $DATASET.haai.db $TMPDIR
exists $DATASET.a[an]i.db && cp $DATASET.a[an]i.db $TMPDIR
exists $DATASET.a[an]i.9[05] && rm $DATASET.a[an]i.9[05]
N=0
function checkpoint_n {
  let N=$N+1
  if [[ $N -ge 10 ]] ; then
    for metric in haai aai ani ; do
      if [[ -s $TMPDIR/$DATASET.$metric.db ]] ; then
        echo "select count(*) from ${metric#h};" \
          | sqlite3 $TMPDIR/$DATASET.$metric.db \
          >/dev/null || exit 1
        cp $TMPDIR/$DATASET.$metric.db .
      fi
    done
    N=0
  fi
}

ESS="../07.annotation/01.function/01.essential"
if [[ $(miga project_info -P "$PROJECT" -m type) != "clade" ]] ; then
  # Classify aai-clade (if project type is not clade)
  CLADES="../10.clades/01.find"
  CLASSIF="."
  [[ -e "$DATASET.aai-medoids.tsv" ]] && rm "$DATASET.aai-medoids.tsv"
  while [[ -e "$CLADES/$CLASSIF/miga-project.medoids" ]] ; do
    MAX_AAI=0
    AAI_MED=""
    AAI_CLS=""
    i_n=0
    for i in $(cat "$CLADES/$CLASSIF/miga-project.medoids") ; do
      let i_n=$i_n+1
      AAI=$(haai $ESS/$DATASET.ess.faa $ESS/$i.ess.faa $CORES \
        $TMPDIR/$DATASET.haai.db $TMPDIR/$DATASET.aai.db)
      [[ "${AAI%.*}" -le 0 ]] \
        && AAI=$(aai ../06.cds/$DATASET.faa ../06.cds/$i.faa $CORES \
        $TMPDIR/$DATASET.aai.db)
      checkpoint_n
      if [[ $(perl -e "print 1 if '$AAI' >= '$MAX_AAI'") == "1" ]] ; then
        MAX_AAI=$AAI
        AAI_MED=$i
        AAI_CLS=$i_n
	echo "[$CLASSIF] New max: $AAI_MED ($AAI_CLS): $MAX_AAI"
      fi
    done
    CLASSIF="$CLASSIF/miga-project.sc-$AAI_CLS"
    echo "$AAI_CLS	$AAI_MED	$MAX_AAI	$CLASSIF" \
      >> "$DATASET.aai-medoids.tsv"
  done

  # Calculate all the AAIs against the lowest subclade (if classified)
  if [[ "$CLASSIF" != "." ]] ; then
    PAR=$(dirname "$CLADES/$CLASSIF")/miga-project.classif
    if [[ -s "$PAR" ]] ; then
      for i in $(cat "$PAR" | awk "\$2==$AAI_CLS{print \$1}") ; do
        aai ../06.cds/$DATASET.faa ../06.cds/$i.faa $CORES \
          $TMPDIR/$DATASET.aai.db > /dev/null
        checkpoint_n
      done
    fi
  fi
else
  # Classify ani-clade (if project type is clade)
  CLADES="../10.clades/02.ani"
  CLASSIF="."
  [[ -e "$DATASET.ani-medoids.tsv" ]] && rm "$DATASET.ani-medoids.tsv"
  while [[ -e "$CLADES/$CLASSIF/miga-project.medoids" ]] ; do
    MAX_ANI=0
    ANI_MED=""
    ANI_CLS=""
    i_n=0
    for i in $(cat "$CLADES/$CLASSIF/miga-project.medoids") ; do
      let i_n=$i_n+1
      ANI=$(ani ../05.assembly/$DATASET.LargeContigs.fna \
        ../05.assembly/$i.LargeContigs.fna $CORES $TMPDIR/$DATASET.ani.db)
      checkpoint_n
      if [[ $(perl -e "print 1 if '$ANI' >= '$MAX_ANI'") == "1" ]] ; then
        MAX_ANI=$ANI
        ANI_MED=$i
        ANI_CLS=$i_n
	echo "[$CLASSIF] New max: $ANI_MED ($ANI_CLS): $MAX_ANI"
      fi
    done
    CLASSIF="$CLASSIF/miga-project.sc-$ANI_CLS"
    echo "$ANI_CLS	$ANI_MED	$MAX_ANI	$CLASSIF" \
      >> "$DATASET.ani-medoids.tsv"
  done

  # Calculate all the ANIs against the lowest subclade (if classified in-clade)
  if [[ "$CLASSIF" != "." ]] ; then
    PAR=$(dirname "$CLADES/$CLASSIF")/miga-project.classif
    if [[ -s "$CLADES/$CLASSIF/miga-project.all" ]] ; then
      for i in $(cat "$PAR" | awk "\$2==$ANI_CLS{print \$1}") ; do
        ani ../05.assembly/$DATASET.LargeContigs.fna \
          ../05.assembly/$i.LargeContigs.fna $CORES \
          $TMPDIR/$DATASET.ani.db > /dev/null
        checkpoint_n
      done
    fi
  fi
fi

#Finalize
N=11
checkpoint_n
