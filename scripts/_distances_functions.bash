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

function make_empty_aai_db {
  local DB=$1
  echo "create table if not exists aai(seq1 varchar(256), seq2 varchar(256)," \
    " aai float, sd float, n int, omega int);" | sqlite3 $DB
}

function ds_name {
  basename $1 | perl -pe "s/[^A-Za-z0-9_].*//"
}

function aai {
  local F1=$1
  local F2=$2
  local TH=$3
  local DB=$4
  local N1=$(ds_name $F1)
  local N2=$(ds_name $F2)
  aai.rb -1 $F1 -2 $F2 -t $TH -a --lookup-first -S $DB --name1 $N1 --name2 $N2 \
    --$MIGA_AAI_SAVE_RBM || echo "0"
}

function ani {
  local F1=$1
  local F2=$2
  local TH=$3
  local DB=$4
  local N1=$(ds_name $F1)
  local N2=$(ds_name $F2)
  ani.rb -1 $F1 -2 $F2 -t $TH -a --no-save-regions --no-save-rbm \
    --lookup-first -S $DB --name1 $N1 --name2 $N2 || echo "0"
}

function haai {
  local F1=$1
  local F2=$2
  local TH=$3
  local DB=$4
  local AAI_DB=$5
  local N1=$(ds_name $F1)
  local N2=$(ds_name $F2)
  local HAAI=$(MIGA_AAI_SAVE_RBM="no-save-rbm" aai $F1 $F2 $TH $DB)
  if [[ "$HAAI" != "" && $(perl -e "print 1 if '$HAAI' <= 90") == "1" ]] ; then
    local AAI=$(perl -e "print (100-exp(2.435076 + 0.4275193*log(100-$HAAI)))")
    [[ ! -s $AAI_DB ]] && make_empty_aai_db $AAI_DB
    echo "insert into aai values('$N1','$N2','$AAI',0,0,0);" | sqlite3 $AAI_DB
    echo $AAI
  fi
}

function val_from_db {
  local N1=$1
  local N2=$2
  local DB=$3
  local MT=$4
  if [[ -s $DB ]] ; then
    echo "select $MT from $MT where seq1='$N1' and seq2='$N2';" \
      | sqlite3 $DB || echo 0
  fi
}

function aai_from_db {
  val_from_db $1 $2 $3 aai
}

function ani_from_db {
  val_from_db $1 $2 $3 ani
}
