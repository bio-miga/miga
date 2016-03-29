#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
set -e
echo "MiGA: $MIGA"
echo "Project: $PROJECT"
source "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/09.distances/03.ani"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "miga-project.start"

echo -n "" > miga-project.log
DS=$(miga list_datasets -P "$PROJECT" --ref --no-multi)

# Extract values
echo "metric a b value sd n omega" | tr " " "\\t" >miga-project.txt
for i in $DS ; do
   echo "SELECT 'ANI', seq1, seq2, ani, sd, n, omega from ani ;" \
      | sqlite3 "$i.db" | tr "\\|" "\\t" >>miga-project.txt
   echo "$i" >> miga-project.log
done

# R-ify
echo "
ani <- read.table('miga-project.txt', sep='\\t', h=T);
save(ani, file='miga-project.Rdata');
h <- hist(ani[,'value'], breaks=100, plot=FALSE);
write.table(
   cbind(h[['breaks']][-length(h[['breaks']])],h[['breaks']][-1],h[['counts']]),
   file='miga-project.hist', quote=FALSE, sep='\\t',
   col.names=FALSE, row.names=FALSE);
" | R --vanilla

# Gzip
gzip -9 -f miga-project.txt

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "miga-project.done"
miga add_result -P "$PROJECT" -r ani_distances

