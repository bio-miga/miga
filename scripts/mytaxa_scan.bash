#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES, $DATASET
set -e
SCRIPT="mytaxa_scan"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
DIR="$PROJECT/data/07.annotation/03.qa/02.mytaxa_scan"
cd "$DIR"

# Initialize
miga date > "$DATASET.start"
if [[ "$MIGA_MYTAXA" == "no" ]] ; then
  echo "This system doesn't currently support MyTaxa." \
    > "$DATASET.nomytaxa.txt"
else
  # Check type of dataset
  NOMULTI=$(miga ls -P "$PROJECT" -D "$DATASET" --no-multi \
    | wc -l | awk '{print $1}')
  if [[ "$NOMULTI" -eq "1" ]] ; then
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
     
    TMPDIR=$(mktemp -d /tmp/MiGA.XXXXXXXXXXXX)
    trap "rm -rf '$TMPDIR'; exit" SIGHUP SIGINT SIGTERM

    FAA="../../../06.cds/$DATASET.faa"
    [[ -s "$FAA" ]] || FAA="${FAA}.gz"
    if [[ ! -s "$DATASET.mytaxa" ]] ; then
      # Execute search
      if [[ ! -s "$DATASET.blast" ]] ; then
        diamond blastp -q "$FAA" -a "$DATASET.daa" -t "$TMPDIR" \
          -d "$DB" -k 5 -p "$CORES" --min-score 60
        diamond view -a "$DATASET.daa" -o "$DATASET.blast" -t "$TMPDIR"
      fi

      # Prepare MyTaxa input, execute MyTaxa, and generate profiles
      perl "$MT/utils/infile_convert.pl" -f no "LOREM_IPSUM" "$DATASET.blast" \
        | sort -k 13 > "$DATASET.mytaxain"
      "$MT/MyTaxa" "$DATASET.mytaxain" "$DATASET.mytaxa" "0.5"
    fi
    ruby "$MIGA/utils/mytaxa_scan.rb" "$FAA" "$DATASET.mytaxa" "$DATASET.wintax"
    echo "
    source('$MIGA/utils/mytaxa_scan.R');
    pdf('$DATASET.pdf', 12, 7);
    mytaxa.scan('$DATASET.wintax');
    dev.off();
    " | R --vanilla

    # Extract genes from flagged regions
    [[ -d "$DATASET.reg" ]] || mkdir "$DATASET.reg"
    if [[ -e "$DATASET.wintax.regions" ]] ; then
      i=0
      for win in $(cat "$DATASET.wintax.regions") ; do
        let i=$i+1
        awk "NR==$win" "$DATASET.wintax.genes" | tr "\\t" "\\n" \
          > "$DATASET.reg/$i.ids"
        if [[ "$FAA" == *.gz ]] ; then
          gzip -cd "$FAA" \
            | FastA.filter.pl -q "$DATASET.reg/$i.ids" /dev/stdin \
            > "$DATASET.reg/$i.faa"
        else
          FastA.filter.pl -q "$DATASET.reg/$i.ids" "$FAA" \
            > "$DATASET.reg/$i.faa"
        fi
      done
      # Archive regions
      tar -c "$DATASET.reg" | gzip -9c > "$DATASET.reg.tar.gz"
      rm -r "$DATASET.reg"
    fi

    # Clean
    for x in daa blast mytaxain wintax wintax.genes wintax.regions ; do
      [[ -e "$DATASET.$x" ]] && rm "$DATASET.$x"
    done
    [[ -s "$DATASET.mytaxa" && ! -s "$DATASET.mytaxa.gz" ]] \
      && gzip -9f "$DATASET.mytaxa"
  fi

fi

# Finalize
miga date > "${DATASET}.done"
cat <<VERSIONS \
  | miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT" -f --stdin-versions
=> MiGA
$(miga --version)
$(
  if [[ "$MIGA_MYTAXA" != "no" && "$NOMULTI" -eq "1" ]] ; then
    echo "=> MyTaxa"
    MyTaxa | grep Version: | perl -pe 's/.*: //'
    echo "=> Diamond"
    diamond --version 2>&1 | perl -pe 's/^diamond version //'
  fi
)
VERSIONS

