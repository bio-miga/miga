#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES, $DATASET
set -e
SCRIPT="cds"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/06.cds"

# Initialize
miga date > "$DATASET.start"

# Gunzip (if necessary)
if [[ -e "../05.assembly/$DATASET.LargeContigs.fna.gz" \
      && ! -e "../05.assembly/$DATASET.LargeContigs.fna" ]] ; then
  gzip -d "../05.assembly/$DATASET.LargeContigs.fna.gz"
  miga add_result -P "$PROJECT" -D "$DATASET" -r assembly -f
fi

# Run Prodigal
TYPE=$(miga ls -P "$PROJECT" -D "$DATASET" -m type | cut -f 2)
case "$TYPE" in
  metagenome|virome)
    $CMD -p meta
    prodigal -a "${DATASET}.faa" -d "${DATASET}.fna" -o "${DATASET}.gff3" \
      -f gff -q -i "../05.assembly/${DATASET}.LargeContigs.fna" -p meta
    ;;
  *)
    P_LEN=0
    BEST_CT=0
    echo "# Codon table selection:" > "${DATASET}.ct.t"
    for ct in 4 11 ; do
      prodigal -a "${DATASET}.faa.$ct" -d "${DATASET}.fna.$ct" \
        -o "${DATASET}.gff3.$ct" -f gff -q -p single -g "$ct" \
        -i "../05.assembly/${DATASET}.LargeContigs.fna"
      C_LEN=$(grep -v '^>' "${DATASET}.faa.$ct" \
        | perl -pe 's/[^A-Z]//ig' | wc -c | awk '{print $1}')
      echo "# codon table $ct total length: $C_LEN aa" \
        >> "${DATASET}.ct.t"
      if [[ $C_LEN > $P_LEN ]] ; then
        for x in faa fna gff3 ; do
          mv "${DATASET}.$x.$ct" "${DATASET}.$x"
        done
        P_LEN=$C_LEN
        BEST_CT=$ct
      else
        rm "$DATASET".*."$ct"
      fi
    done
    echo "Selected codon table: $BEST_CT"
    ;;
esac

# Clean Prodigal noisy deflines
for i in faa fna ; do
  perl -pe 's/>.*ID=([^;]+);.*/>gene_$1/' "$DATASET.$i" > "$DATASET.$i.t"
  mv "$DATASET.$i.t" "$DATASET.$i"
done
perl -pe 's/ID=([0-9]+_[0-9]+);/ID=gene_$1;/' "$DATASET.gff3" \
  > "$DATASET.gff3.t"
mv "$DATASET.gff3.t" "$DATASET.gff3"
if [[ -e "${DATASET}.ct.t" ]] ; then
  cat "${DATASET}.ct.t" >> "${DATASET}.gff3"
  rm "${DATASET}.ct.t"
fi

# Gzip
for ext in gff3 faa fna ; do
  [[ -e "$DATASET.$ext" ]] && gzip -9 -f "$DATASET.$ext"
done

# Finalize
miga date > "$DATASET.done"
miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT" -f

