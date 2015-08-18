#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/09.distances/03.ani"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "miga-project.start"

echo -n "" > "miga-project.log"
DS=$($MIGA/bin/list_datasets -P "$PROJECT" --ref --no-multi)

(
echo "metric	a	b	value	sd	n	omega"
for i in $DS ; do
   echo "select * from ani;" | sqlite3 $i.db
   echo "$i" >> "miga-project.log"
done | tr "\\|" "\\t"
) > "miga-project.txt"

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

