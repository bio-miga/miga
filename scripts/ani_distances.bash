#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
source "$MIGA/scripts/miga.bash"
cd "$PROJECT/data/09.distances/03.ani"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "miga-project.start"

echo "metric	a	b	value	sd	n	omega" > "miga-project.txt"
echo -n "" > "miga-project.log"
DS=$($MIGA/bin/list_datasets -P "$PROJECT" --ref --no-multi)
for i in $DS ; do
   # Check if this is done (e.g., in a previous failed iteration)
   if [[ ! -s "../$i.json" ]] ; then
      echo "$i: Incomplete job, aborting project-wide update..." >&2
      exit 1
   fi
   [[ -d "$i.d" ]] || continue
   
   # Concatenate results
   for j in $DS ; do
      [[ "$i" == "$j" ]] && break # Only lower triangle
      [[ -e "$i.d/$j.txt" ]] || continue # Ignore missing data
      cat "$i.d/$j.txt" >> "miga-project.txt"
   done
   cat $i >> "miga-project.log"
done

# R-ify
echo "
ani <- read.table('miga-project.txt', sep='\\t', h=T)
save(ani, file='miga-project.Rdata')
" | R --vanilla

# Gzip
gzip miga-project.txt

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "miga-project.done"
$MIGA/bin/add_result -P "$PROJECT" -r ani_distances

