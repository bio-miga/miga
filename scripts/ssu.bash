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
  # Run barrnap
  barrnap --quiet --threads "$CORES" "$fa" | grep "^##gff\\|;product=16S " \
    > "$DATASET.ssu.gff"

  # Extract
  bedtools getfasta -s "-fi" "$fa" -bed "$DATASET.ssu.gff" \
    -fo "$DATASET.ssu.all.fa"
  FastA.length.pl "$DATASET.ssu.all.fa" | sort -nr -k 2 | head -n 1 \
    | cut -f 1 > "$DATASET.ssu.fa.id"
  FastA.filter.pl "$DATASET.ssu.fa.id" "$DATASET.ssu.all.fa" > "$DATASET.ssu.fa"
  rm "$DATASET.ssu.fa.id"
  [[ -e "$fa.fai" ]] && rm "$fa.fai"

  # RDP classifier
  if [[ "$MIGA_RDP" == "yes" && -s "$DATASET.ssu.all.fa" ]] ; then
    java -jar $MIGA_HOME/.miga_db/classifier.jar classify \
      -c 0.8 -f fixrank -g 16srrna -o "$DATASET.rdp.tsv" \
      "$DATASET.ssu.all.fa"
    echo "# Version: $(cat $MIGA_HOME/.miga_db/classifier.version.txt \
          | perl -pe 's/.*://' | grep . | paste - - | perl -pe 's/\t/; /')" \
      >> "$DATASET.rdp.tsv"
  fi

  # Gzip
  for x in ssu.gff ssu.all.fa rdp.tsv ; do
    [[ -e "${DATASET}.${x}" ]] && gzip -9 -f "${DATASET}.${x}"
  done
fi

# Finalize
miga date > "$DATASET.done"
miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT" -f
