#!/bin/bash
# Available variables: $PROJECT, $DATASET, $RUNTYPE, $MIGA, $CORES, $TMPDIR,
#                      $NOMULTI, $REF

set -e

if [[ ! -n $MIGA_AAI_SAVE_RBM ]] ; then
  MIGA_AAI_SAVE_RBM="save-rbm"
  if [[ -n $PROJECT ]] ; then
    if [[ $(miga project_info -P "$PROJECT" -m type) != "clade" ]] ; then
      MIGA_AAI_SAVE_RBM="no-save-rbm"
    fi
  fi
fi

fx_exists miga-make_empty_aai_db || function miga-make_empty_aai_db {
  local DB=$1
  echo "create table if not exists aai(seq1 varchar(256), seq2 varchar(256)," \
    " aai float, sd float, n int, omega int);" | sqlite3 $DB
}

fx_exists miga-ds_name || function miga-ds_name {
  basename $1 | perl -pe "s/[^A-Za-z0-9_].*//"
}

fx_exists miga-aai || function miga-aai {
  local F1=$1
  local F2=$2
  local TH=$3
  local DB=$4
  local N1=$(miga-ds_name $F1)
  local N2=$(miga-ds_name $F2)
  aai.rb -1 $F1 -2 $F2 -t $TH -a --lookup-first -S $DB --name1 $N1 --name2 $N2 \
    --$MIGA_AAI_SAVE_RBM || echo "0"
}

fx_exists miga-ani || function miga-ani {
  local F1=$1
  local F2=$2
  local TH=$3
  local DB=$4
  local N1=$(miga-ds_name $F1)
  local N2=$(miga-ds_name $F2)
  ani.rb -1 $F1 -2 $F2 -t $TH -a --no-save-regions --no-save-rbm \
    --lookup-first -S $DB --name1 $N1 --name2 $N2 || echo "0"
}

fx_exists miga-haai || function miga-haai {
  local F1=$1
  local F2=$2
  local TH=$3
  local DB=$4
  local AAI_DB=$5
  local N1=$(miga-ds_name $F1)
  local N2=$(miga-ds_name $F2)
  local HAAI=$(MIGA_AAI_SAVE_RBM="no-save-rbm" miga-aai $F1 $F2 $TH $DB)
  if [[ "$HAAI" != "" && $(perl -e "print 1 if '$HAAI' <= 90") == "1" ]] ; then
    local AAI=$(perl -e "print (100-exp(2.435076 + 0.4275193*log(100-$HAAI)))")
    [[ ! -s $AAI_DB ]] && make_empty_aai_db $AAI_DB
    echo "insert into aai values('$N1','$N2','$AAI',0,0,0);" | sqlite3 $AAI_DB
    echo $AAI
  fi
}

fx_exists miga-haai_or_aai || function miga-haai_or_aai {
  local FH1=$1
  local FH2=$2
  local DBH=$3
  local  F1=$4
  local  F2=$5
  local  DB=$6
  local  TH=$7
  AAI=$(miga-haai $FH1 $FH2 $TH $DBH $DB)
  [[ "${AAI%.*}" -le 0 ]] && AAI=$(miga-aai $F1 $F2 $TH $DB)
  echo $AAI
}

fx_exists miga-val_from_db || function miga-val_from_db {
  local N1=$1
  local N2=$2
  local DB=$3
  local MT=$4
  if [[ -s $DB ]] ; then
    echo "select $MT from $MT where seq1='$N1' and seq2='$N2';" \
      | sqlite3 $DB || echo 0
  fi
}

fx_exists miga-aai_from_db || function miga-aai_from_db {
  miga-val_from_db $1 $2 $3 aai
}

fx_exists miga-ani_from_db || function miga-ani_from_db {
  miga-val_from_db $1 $2 $3 ani
}
