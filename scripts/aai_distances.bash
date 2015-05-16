#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE
source "$(dirname "$0")/miga.bash" # Available variables: $CORES, $MIGA
cd "$PROJECT/data/09.distances/02.aai"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "miga.project.start"

echo -e "metric\ta\tb\tvalue\tsd\tn\tomega" > "miga.project.txt"
echo -n "" > "miga.project.log"
for i in $($MIGA/bin/list_datasets -P "$PROJECT" --ref --no-multi) ; do
   # Check if this is done (e.g., in a previous failed iteration)
   if [[ ! -d "02.aai/$i.d" || ! -s "../$i.json" ]] ; then
      echo "$i: Incomplete job, aborting project-wide update..." >&2
      exit 1
   fi
   
   # Concatenate results
   cat $i.d/*.txt >> "miga.project.txt"
   cat $i >> "miga.project.log"
done

# R-ify
echo "
aai <- read.table('miga.project.txt', sep='\\t', h=T)
save(aai, file='miga.project.Rdata')
" | R --vanilla

# Gzip
gzip miga.project.txt

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "miga.project.done"
$MIGA/bin/add_result -P "$PROJECT" -r aai_distances

