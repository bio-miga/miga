#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES, $DATASET
set -e
SCRIPT="mytaxa"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
DIR="$PROJECT/data/07.annotation/02.taxonomy/01.mytaxa"
[[ -d "$DIR" ]] || mkdir -p "$DIR"
cd "$DIR"

# Initialize
miga date > "$DATASET.start"
if [[ "$MIGA_MYTAXA" == "no" ]] ; then
  echo "This system doesn't currently support MyTaxa." \
    > "$DATASET.nomytaxa.txt"
else
  # Check type of dataset
  MULTI=$(miga ls -P "$PROJECT" -D "$DATASET" --multi \
    | wc -l | awk '{print $1}')
  if [[ "$MULTI" -eq "1" ]] ; then
    # Check requirements
    MT=$(dirname -- "$(which MyTaxa)")
    DB="$MIGA_HOME/.miga_db/AllGenomes.faa.dmnd"
    [[ -e "$DB" ]] || DB="$MT/AllGenomes.faa.dmnd"
    if [[ ! -e "$DB" ]] ; then
      echo "Cannot locate the database: AllGenomes.faa.dmnd:" \
            "no such file or directory" >&2
      exit 1
    fi
    if [[ ! -d "$MT/db" ]] ; then
      echo "Cannot locate the MyTaxa index: $MT/db:" \
            "no such file or directory" >&2
      exit 1
    fi
    if [[ ! -d "$MT/utils" ]] ; then
      echo "Cannot locate the MyTaxa utilities: $MT/utils:" \
            "no such file or directory" >&2
      exit 1
    fi
     
    # Execute search
    FAA="../../../06.cds/$DATASET.faa"
    [[ -s "$FAA" ]] || FAA="${FAA}.gz"
    diamond blastp -q "$FAA" -d "$DB" \
      -a "$DATASET.daa" -k 5 -p "$CORES" --min-score 60
    diamond view -a "$DATASET.daa" -o "$DATASET.blast"

    # Prepare MyTaxa input, execute MyTaxa, and generate profiles
    [[ -e "../../../06.cds/$DATASET.gff2.gz" ]] \
      && [[ ! -e "../../../06.cds/$DATASET.gff2" ]] \
      && gunzip "../../../06.cds/$DATASET.gff2.gz"
    [[ -e "../../../06.cds/$DATASET.gff3.gz" ]] \
      && [[ ! -e "../../../06.cds/$DATASET.gff3" ]] \
      && gunzip "../../../06.cds/$DATASET.gff3.gz"
    if [[ -e "../../../06.cds/$DATASET.gff2" ]] ; then
      # GFF2
      perl "$MT/utils/infile_convert.pl" -f gff2 \
        "../../../06.cds/$DATASET.gff2" "$DATASET.blast" \
        | sort -k 13 > "$DATASET.mytaxain"
      "$MT/MyTaxa" "$DATASET.mytaxain" "$DATASET.mytaxa" "0.5"
      perl "$MT/utils/MyTaxa.distribution.pl" -m "$DATASET.mytaxa" \
        -g "../../../06.cds/$DATASET.gff2" -f gff2 \
        -I "$DATASET.mytaxa.innominate" -G "$DATASET.mytaxa.genes" \
        -K "$DATASET.mytaxa.krona" -u
    elif [[ -e "../../../06.cds/$DATASET.gff3" ]] ; then
      # GFF3
      perl "$MT/utils/infile_convert.pl" -f gff3 \
        "../../../06.cds/$DATASET.gff3" "$DATASET.blast" | sort -k 13 \
        > "$DATASET.mytaxain"
      "$MT/MyTaxa" "$DATASET.mytaxain" "$DATASET.mytaxa" "0.5"
      perl "$MT/utils/MyTaxa.distribution.pl" -m "$DATASET.mytaxa" \
        -g "../../../06.cds/$DATASET.gff3" -f gff3 \
        -I "$DATASET.mytaxa.innominate" -G "$DATASET.mytaxa.genes" \
        -K "$DATASET.mytaxa.krona" -u
    else
      # No GFF
      perl "$MT/utils/infile_convert.pl" -f no "LOREM_IPSUM" "$DATASET.blast" \
        | sort -k 13 > "$DATASET.mytaxain"
      "$MT/MyTaxa" "$DATASET.mytaxain" "$DATASET.mytaxa" "0.5"
      perl "$MT/utils/MyTaxa.distribution.pl" -m "$DATASET.mytaxa" \
        -I "$DATASET.mytaxa.innominate" -G "$DATASET.mytaxa.genes" \
        -K "$DATASET.mytaxa.krona" -u
    fi

    # Execute Krona
    ktImportText -o "$DATASET.html" -n biota "$DATASET.mytaxa.krona,$DATASET"

    # Gzip and cleanup
    for i in "../../../06.cds/$DATASET.gff2" "../../../06.cds/$DATASET.gff3" \
             "$DATASET.mytaxain" "$DATASET.blast" ; do
      [[ -e $i ]] && gzip -9f $i
    done
    rm "$DATASET.daa"
  fi

fi

# Finalize
miga date > "${DATASET}.done"
cat <<VERSIONS \
  | miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT" -f --stdin-versions
=> MiGA
$(miga --version)
$(
  if [[ "$MIGA_MYTAXA" != "no" && "$MULTI" -eq "1" ]] ; then
    echo "=> MyTaxa"
    MyTaxa | grep Version: | perl -pe 's/.*: //'
    echo "=> Diamond"
    diamond --version 2>&1 | perl -pe 's/^diamond version //'
    echo "=> Krona"
    ktImportText | head -n 2 | tail -n 1 | awk '{ print $3 }'
  fi
)
VERSIONS

