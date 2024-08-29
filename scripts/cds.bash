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

# Check if the input assembly is empty
ASM_LEN=$(grep -v '^>' "../05.assembly/${DATASET}.LargeContigs.fna" \
            | wc -lc | awk '{ print $2-$1 }')
if [[ "$ASM_LEN" -lt 1 ]] ; then
  miga edit -P "$PROJECT" -D "$DATASET" --inactivate "Empty assembly"
  exit 0
fi

# Run Prodigal
TYPE=$(miga ls -P "$PROJECT" -D "$DATASET" -m type | cut -f 2)
case "$TYPE" in
  metagenome|virome|plasmid)
    prodigal -a "${DATASET}.faa" -d "${DATASET}.fna" -o "${DATASET}.gff3" \
      -f gff -q -i "../05.assembly/${DATASET}.LargeContigs.fna" -p meta
    ;;
  *)
    P_LEN=0
    BEST_CT=0
    PROCEDURE=single
    [[ "$ASM_LEN" -lt 2000 ]] && PROCEDURE=meta
    echo "# Codon table selection:" > "${DATASET}.ct.t"
    for ct in 11 4 ; do
      prodigal -a "${DATASET}.faa.$ct" -d "${DATASET}.fna.$ct" \
        -o "${DATASET}.gff3.$ct" -f gff -q -p $PROCEDURE -g "$ct" \
        -i "../05.assembly/${DATASET}.LargeContigs.fna"
      C_LEN=$(grep -v '^>' "${DATASET}.faa.$ct" \
        | perl -pe 's/[^A-Z]//ig' | wc -c | awk '{print $1}')
      echo "# codon table $ct total length: $C_LEN aa" \
        >> "${DATASET}.ct.t"
      if [[ $C_LEN -gt $(($P_LEN * 11 / 10)) ]] ; then
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
  [[ -e "$DATASET.$ext" ]] && gzip -9f "$DATASET.$ext"
done

# Finalize
miga date > "${DATASET}.done"
cat <<VERSIONS \
  | miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT" -f --stdin-versions
=> MiGA
$(miga --version)
=> Prodigal
$(prodigal -v 2>&1 | grep . | perl -pe 's/^Prodigal //')
VERSIONS

