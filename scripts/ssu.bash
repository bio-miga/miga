#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES, $DATASET
set -e
SCRIPT="ssu"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
DIR="$PROJECT/data/07.annotation/01.function/02.ssu"
[[ -d "$DIR" ]] || mkdir -p "$DIR"
cd "$DIR"

# Initialize
miga date > "$DATASET.start"

fa="../../../05.assembly/$DATASET.LargeContigs.fna"
if [[ -s $fa ]] ; then
  # Get domain
  d="$(miga ls -P "$PROJECT" -D "$DATASET" -m tax:d | awk '{print $2}')"
  if [[ "$d" != "Bacteria" && "$d" != "Archaea" && "$d" != "Eukaryota" ]] ; then
    d="Bacteria" # Assume Bacteria in the absence of additional information
  fi

  # Run barrnap
  dom_opt="$(echo "$d" | perl -ne 'print lc' | head -c 3)"
  barrnap --quiet --kingdom "$dom_opt" --threads "$CORES" "$fa" \
    > "${DATASET}.gff"

  # Extract
  grep "^##gff\\|;product=16S " < "${DATASET}.gff" \
    | bedtools getfasta -s "-fi" "$fa" -bed /dev/stdin \
      -fo "${DATASET}.ssu.all.fa"
  FastA.length.pl "${DATASET}.ssu.all.fa" | sort -nr -k 2 | head -n 1 \
    | cut -f 1 > "${DATASET}.ssu.fa.id"
  FastA.filter.pl "${DATASET}.ssu.fa.id" "${DATASET}.ssu.all.fa" \
    > "${DATASET}.ssu.fa"
  rm "${DATASET}.ssu.fa.id"
  [[ -e "${fa}.fai" ]] && rm "${fa}.fai"

  # RDP classifier
  if [[ "$MIGA_RDP" == "yes" && -s "${DATASET}.ssu.all.fa" ]] ; then
    java -jar "$MIGA_HOME/.miga_db/classifier.jar" classify \
      -c 0.8 -f fixrank -g 16srrna -o "${DATASET}.rdp.tsv" \
      "${DATASET}.ssu.all.fa"
    echo "# Version: $(perl -pe 's/.*://' \
          < "$MIGA_HOME/.miga_db/classifier.version.txt" \
          | grep . | paste - - | perl -pe 's/\t/; /')" \
      >> "${DATASET}.rdp.tsv"
  fi

  # tRNAscan-SE
  dom_opt="-$(echo "$d" | perl -pe 's/(\S).*/$1/')"
  out="${DATASET}.trna.txt"
  # `echo O` is to avoid a hang from a pre-existing output file.
  # This is better than pre-checking (and removing), because it avoids
  # the (unlikely) scenario of a file racing (e.g., a file created right
  # before tRNAscan-SE starts, or a `rm` failure).
  #
  # The trailing `|| true` is to treat failure as non-fatal
  echo O | tRNAscan-SE $dom_opt -o "${DATASET}.trna.txt" -q "$fa" || true

  # Gzip
  for x in gff ssu.all.fa rdp.tsv trna.txt ; do
    [[ -e "${DATASET}.${x}" ]] && gzip -9 -f "${DATASET}.${x}"
  done
fi

# Finalize
miga date > "${DATASET}.done"
miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT" -f
