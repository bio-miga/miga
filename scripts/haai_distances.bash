#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/09.distances/01.haai"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "miga-project.start"

echo -n "" > "miga-project.log"
DS=$($MIGA/bin/list_datasets -P "$PROJECT" --ref --no-multi)
for i in $DS ; do
   if [[ ! -s "miga-project.$i.txt" ]] ; then
      # Check if this dataset is done (e.g., in a previous failed iteration)
      if [[ ! -s "../$i.json" ]] ; then
	 echo "$i: Incomplete job, aborting project-wide update..." >&2
	 exit 1
      fi
      [[ -d "$i.d" ]] || continue
      
      # Concatenate results
      [[ -e "miga-project.$i.txt.tmp" ]] && rm "miga-project.$i.txt.tmp"
      for j in $DS ; do
	 [[ "$i" == "$j" ]] && break # Only lower triangle
	 if [[ -e "$i.d/$j.txt" ]] ; then
	    cat "$i.d/$j.txt" >> "miga-project.$i.txt.tmp"
	 elif [[ -e "$j.d/$i.txt" ]] ; then
	    cat "$j.d/$i.txt" >> "miga-project.$i.txt.tmp"
	 else
	    continue # Ignore missing data
	 fi
      done
      mv "miga-project.$i.txt.tmp" "miga-project.$i.txt"
   fi
   echo "$i" >> "miga-project.log"
done

# Merge
echo "metric	a	b	value	sd	n	omega" > "miga-project.txt"
cat "miga-project.*.txt" | grep . | perl -pe "s/ /\\t/g" >> "miga-project.txt"
rm "miga-project.*.txt"

# R-ify
echo "
haai <- read.table('miga-project.txt', sep='\\t', h=T)
save(haai, file='miga-project.Rdata')
" | R --vanilla

# Gzip
gzip -9 -f miga-project.txt

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "miga-project.done"
$MIGA/bin/add_result -P "$PROJECT" -r haai_distances

