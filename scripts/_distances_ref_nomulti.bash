#!/bin/bash
# Available variables: $PROJECT, $DATASET, $RUNTYPE, $MIGA, $CORES, $TMPDIR,
# 			$NOMULTI, $REF

set -e

fx_exists miga-checkpoint_n || function miga-checkpoint_n {
  if [[ $N -eq 10 ]] ; then
    for t in 01.haai 02.aai 03.ani ; do
      if [[ -s $TMPDIR/$t.db ]] ; then
        tab="aai"
        [[ "$t" == "03.ani" ]] && tab="ani"
        echo "select count(*) from $tab;" \
          | sqlite3 "$TMPDIR/$t.db" \
          >/dev/null || exit 1
        cp "$TMPDIR/$t.db" "$t/$DATASET.db"
      fi
    done
    N=0
  fi
  let N=$N+1
}

ESS="../07.annotation/01.function/01.essential"

# Initialize temporals
for t in 01.haai 02.aai 03.ani ; do
  [[ -s $t/$DATASET.db ]] && cp "$t/$DATASET.db" "$TMPDIR/$t.db"
done
N=1

# Traverse "nearly-half" of the ref-datasets using first-come-first-served
for i in $(miga list_datasets -P "$PROJECT" --ref --no-multi) ; do
  echo "[ $(date "+%Y-%m-%d %H:%M:%S %z") ] $i"
  AAI=""; ANI="";
  # Check if the i-th dataset is ready
  [[ -s $ESS/$i.done && -s $ESS/$i.json ]] || continue
  # Check if this is done (e.g., in a previous failed iteration)
  AAI=$(miga-aai_from_db "$DATASET" "$i" "$TMPDIR/02.aai.db")
  # Try the other direction
  [[ "${AAI%.*}" -le 0 ]] \
    && AAI=$(miga-aai_from_db "$i" "$DATASET" "02.aai/$i.db")
  # Try with hAAI
  if [[ "${AAI%.*}" -le 0 ]] ; then
    [[ -e "$TMPDIR/$DATASET.ess.faa" ]] \
      || cp "$ESS/$DATASET.ess.faa" "$TMPDIR/$DATASET.ess.faa"
    AAI=$(miga-haai "$TMPDIR/$DATASET.ess.faa" "$ESS/$i.ess.faa" \
      "$CORES" "$TMPDIR/01.haai.db" "$TMPDIR/02.aai.db")
  fi
  # Try with complete AAI
  if [[ "${AAI%.*}" -le 0 ]] ; then
    [[ -e "$TMPDIR/$DATASET.faa" ]] \
      || cp "../06.cds/$DATASET.faa" "$TMPDIR/$DATASET.faa"
    AAI=$(miga-aai "$TMPDIR/$DATASET.faa" "../06.cds/$i.faa" \
      "$CORES" "$TMPDIR/02.aai.db")
  fi
  # Check if ANI is meaningful
  if [[ -e "../05.assembly/$DATASET.LargeContigs.fna" \
      && -e "../05.assembly/$i.LargeContigs.fna" \
      && $(perl -e "print 1 if '$AAI' >= 90") == "1" ]] ; then
    # Check if this is done (e.g., in a previous failed iteration)
    ANI=$(miga-ani_from_db "$DATASET" "$i" "$TMPDIR/03.ani.db")
    # Try the other direction
    [[ "${ANI%.*}" -le 0 ]] \
      && ANI=$(miga-ani_from_db "$i" "$DATASET" "03.ani/$i.db")
    # Calculate it
    if [[ "${ANI%.*}" -le 0 ]] ; then
      [[ -e "$TMPDIR/$DATASET.LargeContigs.fna" ]] \
        || cp "../05.assembly/$DATASET.LargeContigs.fna" \
          "$TMPDIR/$DATASET.LargeContigs.fna"
      ANI=$(miga-ani "$TMPDIR/$DATASET.LargeContigs.fna" \
        "../05.assembly/$i.LargeContigs.fna" "$CORES" "$TMPDIR/03.ani.db")
    fi
  fi
  miga-checkpoint_n
done
N=10
miga-checkpoint_n

