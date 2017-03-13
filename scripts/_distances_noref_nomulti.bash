#!/bin/bash
# Available variables: $PROJECT, $DATASET, $RUNTYPE, $MIGA, $CORES, $TMPDIR,
#                      $NOMULTI, $REF

set -e

# Deal with previous runs (if any)
exists "$DATASET".haai.db && cp "$DATASET".haai.db "$TMPDIR"
exists "$DATASET".a[an]i.db && cp "$DATASET".a[an]i.db "$TMPDIR"
exists "$DATASET".a[an]i.9[05] && rm "$DATASET".a[an]i.9[05]
N=0
fx_exists miga-checkpoint_n || function miga-checkpoint_n {
  let N=$N+1
  if [[ $N -ge 10 ]] ; then
    for metric in haai aai ani ; do
      if [[ -s $TMPDIR/$DATASET.$metric.db ]] ; then
        echo "select count(*) from ${metric#h};" \
          | sqlite3 "$TMPDIR/$DATASET.$metric.db" \
          >/dev/null || exit 1
        cp "$TMPDIR/$DATASET.$metric.db" .
      fi
    done
    N=0
  fi
}

fx_exists miga-noref_haai_or_aai || function miga-noref_haai_or_aai {
  local Q=$1
  local S=$2
  [[ -s $TMPDIR/$Q.faa ]] \
    || cp "../06.cds/$Q.faa" "$TMPDIR/$Q.faa"
  miga-haai_or_aai "$ESS/$Q.ess.faa" "$ESS/$S.ess.faa" "$TMPDIR/$Q.haai.db" \
    "$TMPDIR/$Q.faa" "../06.cds/$S.faa" "$TMPDIR/$Q.aai.db" "$CORES"
}

fx_exists miga-noref_ani || function miga-noref_ani {
  local Q=$1
  local S=$2
  [[ -s $TMPDIR/$Q.LargeContigs.fna ]] \
    || cp ../05.assembly/$Q.LargeContigs.fna "$TMPDIR/$Q.LargeContigs.fna"
  miga-ani "$TMPDIR/$Q.LargeContigs.fna" "../05.assembly/$S.LargeContigs.fna" \
    "$CORES" "$TMPDIR/$Q.ani.db"
}



# Calculate the classification-informed AAI/ANI traverse (if not classified)
ESS="../07.annotation/01.function/01.essential"
if [[ $(miga project_info -P "$PROJECT" -m type) != "clade" ]] ; then
  # Classify aai-clade (if project type is not clade)
  CLADES="../10.clades/01.find"
  METRIC="aai"
else
  # Classify ani-clade (if project type is clade)
  CLADES="../10.clades/02.ani"
  METRIC="ani"
fi

CLASSIF="."
[[ -e "$DATASET.$METRIC-medoids.tsv" ]] && rm "$DATASET.$METRIC-medoids.tsv"
while [[ -e "$CLADES/$CLASSIF/miga-project.medoids" ]] ; do
  MAX_VAL=0
  VAL_MED=""
  VAL_CLS=""
  i_n=0
  while read i ; do
    let i_n=$i_n+1
    if [[ $METRIC == "aai" ]] ; then
      VAL=$(miga-noref_haai_or_aai "$DATASET" "$i")
    else
      VAL=$(miga-noref_ani "$DATASET" "$i")
    fi
    miga-checkpoint_n
    if [[ $(perl -e "print 1 if '$VAL' >= '$MAX_VAL'") == "1" ]] ; then
      MAX_VAL=$VAL
      VAL_MED=$i
      VAL_CLS=$i_n
      echo "[$CLASSIF] New max: $VAL_MED ($VAL_CLS): $MAX_VAL"
    fi
  done < "$CLADES/$CLASSIF/miga-project.medoids"
  CLASSIF="$CLASSIF/miga-project.sc-$VAL_CLS"
  echo "$VAL_CLS	$VAL_MED	$MAX_VAL	$CLASSIF" \
    >> "$DATASET.$METRIC-medoids.tsv"
done

# Calculate all the AAIs/ANIs against the lowest subclade (if classified)
if [[ "$CLASSIF" != "." ]] ; then
  PAR=$(dirname "$CLADES/$CLASSIF")/miga-project.classif
  if [[ -s "$PAR" ]] ; then
    while read i ; do
      if [[ $METRIC == "aai" ]] ; then
        AAI=$(miga-noref_haai_or_aai "$DATASET" "$i")
      else
        AAI=100
      fi
      if [[ $(perl -e "print 1 if '$AAI' >= 90") == "1" ]] ; then
        miga-noref_ani "$DATASET" "$i"
      fi
      miga-checkpoint_n
    done < <(awk "\$2==$VAL_CLS{print \$1}" < "$PAR")
  fi
fi

#Finalize
N=11
miga-checkpoint_n
