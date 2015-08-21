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

echo "metric	a	b	value	sd	n	omega" \
   > miga-project.txt
for i in $DS ; do
   echo "select * from aai;" | sqlite3 $i.db \
      | tr "\\|" "\\t" \
      >> miga-project.txt
   echo "$i" >> "miga-project.log"
done

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

