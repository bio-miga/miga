#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/02.trimmed_reads"

b=$DATASET

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.start"

# Unzip (if necessary)
[[ -e ../01.raw_reads/$b.1.fastq.gz && ! -e ../01.raw_reads/$b.1.fastq ]] && gunzip ../01.raw_reads/$b.1.fastq.gz
[[ -e ../01.raw_reads/$b.2.fastq.gz && ! -e ../01.raw_reads/$b.2.fastq ]] && gunzip ../01.raw_reads/$b.2.fastq.gz

# Clean existing files
exists $b.[12].* && rm $b.[12].*

# Tag
FastQ.tag.rb -i ../01.raw_reads/$b.1.fastq -p "$b-" -s "/1" -o $b.1.fastq
[[ -e ../01.raw_reads/$b.2.fastq ]] && FastQ.tag.rb -i ../01.raw_reads/$b.2.fastq -p "$b-" -s "/2" -o $b.2.fastq

# Trim
SolexaQA++ dynamictrim $b.[12].fastq -h 20 -d .
SolexaQA++ lengthsort $b.[12].fastq.trimmed -l 50 -d .

# Clean adapters
if [[ -e $b.2.fastq.trimmed.paired ]] ; then
   scythe -a $MIGA/utils/adapters.fa $b.1.fastq.trimmed.paired > $b.1.clipped.all.fastq
   scythe -a $MIGA/utils/adapters.fa $b.2.fastq.trimmed.paired > $b.2.clipped.all.fastq
   SolexaQA++ lengthsort $b.[12].clipped.all.fastq -l 50 -d .
   rm $b.[12].clipped.all.fastq
   [[ -e $b.1.clipped.all.fastq.single ]] && mv $b.1.clipped.all.fastq.single $b.1.clipped.single.fastq
   [[ -e $b.2.clipped.all.fastq.single ]] && mv $b.2.clipped.all.fastq.single $b.2.clipped.single.fastq
   mv $b.1.clipped.all.fastq.paired $b.1.clipped.fastq
   mv $b.2.clipped.all.fastq.paired $b.2.clipped.fastq
   rm $b.1.clipped.all.fastq.summary.txt &>/dev/null
else
   scythe -a $MIGA/utils/adapters.fa $b.1.fastq.trimmed.single > $b.1.clipped.all.fastq
   SolexaQA++ lengthsort $b.1.clipped.all.fastq -l 50 -d .
   mv $b.1.clipped.all.fastq.single $b.1.clipped.fastq
fi
rm $b.[12].*.discard &>/dev/null

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.done"
$MIGA/bin/add_result -P "$PROJECT" -D "$DATASET" -r trimmed_reads

