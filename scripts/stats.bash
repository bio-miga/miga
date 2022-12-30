#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES, $DATASET
set -e
SCRIPT="stats"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
DIR="$PROJECT/data/90.stats"
[[ -d "$DIR" ]] || mkdir -p "$DIR"
cd "$DIR"

# Initialize
miga date > "${DATASET}.start"

# tRNAscan-SE
fa="../05.assembly/${DATASET}.LargeContigs.fna"
if [[ -s "$fa" ]] ; then
  d="$(miga ls -P "$PROJECT" -D "$DATASET" -m tax:d | awk '{print $2}')"
  if [[ "$d" == "Bacteria" || "$d" == "Archaea" || "$d" == "Eukaryota" ]] ; then
    dom_opt="-$(echo "$d" | perl -pe 's/(\S).*/$1/')"
    out="${DATASET}.trna.txt"
    # `echo O` is to avoid a hang from a pre-existing output file.
    # This is better than pre-checking (and removing), because it avoids
    # the (unlikely) scenario of a file racing (e.g., a file created right
    # before tRNAscan-SE starts, or a `rm` failure).
    #
    # The trailing `|| true` is to treat failure as non-fatal
    echo O | tRNAscan-SE $dom_opt -o "$out" -q "$fa" || true
    if [[ -s "$out" ]] ; then
      cnt=$(tail -n +4 "$out" | wc -l | awk '{print $1}')
      aa="$(tail -n +4 "$out" | grep -v 'pseudo$' | awk '{print $5}' \
               | grep -v 'Undet' | perl -pe 's/^f?([A-Za-z]+)[0-9]?/$1/' \
               | sort | uniq | wc -l | awk '{print $1}')"
      miga edit -P "$PROJECT" -D "$DATASET" \
        -m "trna_count=Int($cnt),trna_aa=Int($aa)"
    fi
  fi
fi

# Calculate statistics
for i in raw_reads trimmed_fasta assembly cds essential_genes ssu distances taxonomy ; do
  echo "# $i"
  miga stats --compute-and-save --ignore-empty -P "$PROJECT" -D "$DATASET" -r $i
done

# Finalize
miga date > "$DATASET.done"
miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT" -f
