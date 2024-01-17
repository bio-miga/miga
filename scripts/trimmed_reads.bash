#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES, $DATASET
set -e
SCRIPT="trimmed_reads"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/02.trimmed_reads"

b=$DATASET

# Initialize
miga date > "$DATASET.start"

# Clean existing files
exists "$b".[12].* && rm "$b".[12].*

# Gzip (if necessary)
for s in 1 2 ; do
  in="../01.raw_reads/${b}.${s}.fastq"
  if [[ -s "$in" ]] ; then
    gzip -9f "$in"
    miga add_result -P "$PROJECT" -D "$DATASET" -r raw_reads -f
  fi
done

# Tag
in1="../01.raw_reads/$b.1.fastq.gz"
in2="../01.raw_reads/$b.2.fastq.gz"
FastQ.tag.rb -i "$in1" -p "$b-" -s "/1" -o "$b.1.fastq.gz"
[[ -e "$in2" ]] && FastQ.tag.rb -i "$in2" -p "$b-" -s "/2" -o "$b.2.fastq.gz"

# Multitrim
CMD="multitrim.py --zip gzip --level 9 --threads $CORES -o $b"
if [[ -s "$b.2.fastq.gz" ]] ; then
  # Paired
  $CMD -1 "$b.1.fastq.gz" -2 "$b.2.fastq.gz"
  for s in 1 2 ; do
    mv "$b/${s}.post_trim_${b}.${s}.fq.gz" "${b}.${s}.clipped.fastq.gz"
    mv "$b/${s}.pre_trim_QC_${b}.${s}.html" \
       "../03.read_quality/${b}.pre.${s}.html"
    mv "$b/${s}.post_trim_QC_${b}.${s}.html" \
       "../03.read_quality/${b}.post.${s}.html"
  done
else
  # Unpaired
  $CMD -u "$b.1.fastq.gz"
  mv "$b/unpaired.post_trim_${b}.1.fq.gz" "${b}.1.clipped.fastq.gz"
  mv "$b/unpaired.pre_trim_QC_${b}.1.html" \
     "../03.read_quality/${b}.pre.1.html"
  mv "$b/unpaired.post_trim_QC_${b}.1.html" \
     "../03.read_quality/${b}.post.1.html"
fi
mv "$b/Subsample_Adapter_Detection.stats.txt" \
  "../03.read_quality/$b.adapters.txt"

# Cleanup
rm -r "$b"
rm -f "$b".[12].fastq.gz

# Finalize
miga date > "${DATASET}.done"
cat <<VERSIONS \
  | miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT" -f --stdin-versions
=> MiGA
$(miga --version)
=> Enveomics Collection: FastQ.tag.rb
$(FastQ.tag.rb --version | perl -pe 's/.* //')
=> Multitrim
version unknown
=> FaQCs
$(FaQCs --version 2>&1 | perl -pe 's/.*: //')
=> Seqtk
$(seqtk 2>&1 | grep Version | perl -pe 's/.*: //')
=> Fastp
$(fastp --version 2>&1 | perl -pe 's/^fastp //')
=> Falco
$(falco -V 2>&1 | tee)
VERSIONS

