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
TR="../02.trimmed_reads"
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
for i in 1 2 ; do
  base="$TR/${DATASET}.${i}.clipped.fastq"
  if [[ -e "$base" && ! -s "${base}.gz" ]] ; then
    gzip -9f "$base"
    miga add_result -P "$PROJECT" -D "$DATASET" -r trimmed_reads -f
  fi
done

# Assemble
CMD="spades.py -o $DATASET -t $CORES"
TYPE_OPT=""
case "$(miga ls -P "$PROJECT" -D "$DATASET" -m type | cut -f 2)" in
  "metagenome")
    TYPE_OPT="--meta" ;;
  "plasmid")
    TYPE_OPT="--plasmid" ;;
  "scgenome")
    TYPE_OPT="--sc" ;;
  "genome")
    TYPE_OPT="--isolate" ;;
  "virome")
    TYPE_OPT="--metaviral" ;;
esac
F1="$TR/${DATASET}.1.clipped.fastq.gz"
F2="$TR/${DATASET}.2.clipped.fastq.gz"
if [[ -s "$F1" ]] ; then
  if [[ -s "$F2" ]] ; then
    CMD="$CMD -1 $F1 -2 $F2"
  else
    CMD="$CMD -s $F1"
    [[ "$TYPE_OPT" == "--meta" ]] && TYPE_OPT=""
  fi
else
  F1="$TF/${DATASET}.CoupledReads.fa.gz"
  F1="$TF/${DATASET}.SingleReads.fa.gz"
  if [[ -s "$F1" ]] ; then
    CMD="$CMD --12 $F1"
  elif [[ -s "$F2" ]] ; then
    CMD="$CMD -s $F2"
    [[ "$TYPE_OPT" == "--meta" ]] && TYPE_OPT=""
  else
    echo "No input files found to assemble" >&2
    exit 1
  fi
fi
CMD="$CMD $TYPE_OPT"
echo "$CMD"
$CMD || true
[[ -s "$DATASET/contigs.fasta" ]] || exit 1

# Clean
KEEP_GR=$(miga option -P "$PROJECT" -D "$DATASET" -k keep_assembly_graphs)
[[ "$KEEP_GR" == "true" ]] || ( cd "$DATASET" && rm -R *.gfa *.fastg *.paths )
( cd "$DATASET" && rm -R K* corrected misc pipeline_state before_rr.fasta )

# Extract
if [[ -s "$DATASET/scaffolds.fasta" ]] ; then
  ln -s "$DATASET/scaffolds.fasta" "$DATASET.AllContigs.fna"
else
  ln -s "$DATASET/contigs.fasta" "$DATASET.AllContigs.fna"
fi
FastA.length.pl "$DATASET.AllContigs.fna" | awk '$2 >= 1000 { print $1 }' \
  | FastA.filter.pl /dev/stdin "$DATASET.AllContigs.fna" \
  > "$DATASET.LargeContigs.fna"

# Finalize
miga date > "$DATASET.done"
[[ -n "$OPT_TYPE" ]] || OPT_TYPE="default"
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
=> SPADES
$(spades.py --version | perl -pe 's/.* //') [$OPT_TYPE]
VERSIONS
