#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/09.distances/03.ani"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "miga-project.start"

echo "metric	a	b	value	sd	n	omega" > "miga-project.txt.tmp"
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
      if [[ -e "$i.d/$j.txt" ]] ; then
	 cat "$i.d/$j.txt" >> "miga-project.txt.tmp"
      elif [[ -e "$j.d/$i.txt" ]] ; then
	 cat "$j.d/$i.txt" >> "miga-project.txt.tmp"
      else
	 continue # Ignore missing data
      fi
      echo "" >> "miga-project.txt.tmp"
   done
   echo "$i" >> "miga-project.log"
done

cat "miga-project.txt.tmp" | grep . | perl -pe "s/\\s/\\t/g" > "miga-project.txt"
rm "miga-project.txt.tmp"
# R-ify
echo "
ani <- read.table('miga-project.txt', sep='\\t', h=T)
save(ani, file='miga-project.Rdata')
" | R --vanilla

# Gzip
gzip -9 -f miga-project.txt

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "miga-project.done"
$MIGA/bin/add_result -P "$PROJECT" -r ani_distances

