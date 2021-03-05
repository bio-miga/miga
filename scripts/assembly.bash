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
    FastA.interpose.pl "$cr" "$b".[12].tmp
    rm "$b".[12].tmp
    miga add_result -P "$PROJECT" -D "$DATASET" -r trimmed_fasta -f
  fi
fi

# Assemble
FA="$TF/$DATASET.CoupledReads.fa"
[[ -e "$FA" ]] || FA="$FA.gz"
[[ -e "$FA" ]] || FA="../04.trimmed_fasta/$DATASET.SingleReads.fa"
[[ -e "$FA" ]] || FA="$FA.gz"
RD="r"
[[ $FA == *.SingleReads.fa* ]] && RD="l"
idba_ud --pre_correction -$RD "$FA" -o "$DATASET" --num_threads "$CORES" || true
[[ -s "$DATASET/contig.fa" ]] || exit 1

# Clean
( cd "$DATASET" && rm kmer graph-*.fa align-* local-contig-*.fa contig-*.fa )

# Extract
if [[ -s "$DATASET/scaffold.fa" ]] ; then
  ln -s "$DATASET/scaffold.fa" "$DATASET.AllContigs.fna"
else
  ln -s "$DATASET/contig.fa" "$DATASET.AllContigs.fna"
fi
FastA.length.pl "$DATASET.AllContigs.fna" | awk '$2>=1000{print $1}' \
  | FastA.filter.pl /dev/stdin "$DATASET.AllContigs.fna" \
  > "$DATASET.LargeContigs.fna"

# Finalize
miga date > "$DATASET.done"
miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT" -f

