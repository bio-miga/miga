#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES, $DATASET
set -e
SCRIPT="assembly"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/05.assembly"

# Initialize
miga date > "$DATASET.start"

# Interpose (if needed)
interpose=no
TF="../04.trimmed_fasta"
b=$DATASET
if [[ -s "$TF/${b}.2.fasta" || -s "$TF/${b}.2.fasta.gz" ]] ; then
  cr="$TF/${b}.CoupledReads.fa"
  if [[ ! -s "$cr" && ! -s "${cr}.gz" ]] ; then
    for s in 1 2 ; do
      if [[ -s "$TF/${b}.${s}.fasta" ]] ; then
        ln -s "$TF/${b}.${s}.fasta" "${b}.${s}.tmp"
      else
        gzip -cd "$TF/${b}.${s}.fasta.gz" > "${b}.${s}.tmp"
      fi
    done
    interpose=yes
    FastA.interpose.pl "$cr" "$b".[12].tmp
    rm "$b".[12].tmp
    miga add_result -P "$PROJECT" -D "$DATASET" -r trimmed_fasta -f
  fi
fi

# Gzip (if needed)
for i in SingleReads CoupledReads ; do
  base="$TF/${DATASET}.${i}.fa"
  if [[ -e "$base" && ! -s "${base}.gz" ]] ; then
    gzip -9f "$base"
    miga add_result -P "$PROJECT" -D "$DATASET" -r trimmed_fasta -f
  fi
done

# Assemble
FA="$TF/${DATASET}.CoupledReads.fa.gz"
[[ -e "$FA" ]] || FA="$TF/${DATASET}.SingleReads.fa.gz"
RD="r"
[[ $FA == *.SingleReads.fa* ]] && RD="l"
gzip -cd "$FA" \
  | idba_ud --pre_correction -$RD /dev/stdin \
    -o "$DATASET" --num_threads "$CORES" || true
[[ -s "$DATASET/contig.fa" ]] || exit 1

# Clean
( cd "$DATASET" && rm kmer graph-*.fa align-* local-contig-*.fa contig-*.fa )

# Extract
if [[ -s "$DATASET/scaffold.fa" ]] ; then
  ln -s "$DATASET/scaffold.fa" "$DATASET.AllContigs.fna"
else
  ln -s "$DATASET/contig.fa" "$DATASET.AllContigs.fna"
fi
FastA.length.pl "$DATASET.AllContigs.fna" | awk '$2 >= 1000 { print $1 }' \
  | FastA.filter.pl /dev/stdin "$DATASET.AllContigs.fna" \
  > "$DATASET.LargeContigs.fna"

# Finalize
miga date > "$DATASET.done"
cat <<VERSIONS \
  | miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT" -f --stdin-versions
=> MiGA
$(miga --version)
$(
  if [[ "$interpose" == "yes" ]] ; then
    echo "=> Enveomics Collection: FastA.interpose.pl"
    echo "version unknown"
  fi
)
=> IDBA-UD
version unknown
VERSIONS

