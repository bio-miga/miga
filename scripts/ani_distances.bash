#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
set -e
SCRIPT="ani_distances"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/09.distances/03.ani"

# Initialize
miga date > "miga-project.start"

echo -n "" > miga-project.log
DS=$(miga ls -P "$PROJECT" --ref --no-multi --active)

# Extract values
echo "metric a b value sd n omega" | tr " " "\\t" >miga-project.txt
for i in $DS ; do
  echo "SELECT 'ANI', seq1, seq2, ani, sd, n, omega from ani ;" \
    | sqlite3 "$i.db" | tr "\\|" "\\t" >>miga-project.txt
  echo "$i" >> miga-project.log
done

# R-ify
echo "
ani <- read.table('miga-project.txt', sep='\\t', h=T, as.is=TRUE);
save(ani, file='miga-project.Rdata');
if(sum(ani[,'a'] != ani[,'b']) > 0){
  h <- hist(ani[ani[,'a'] != ani[,'b'], 'value'], breaks=100, plot=FALSE);
  write.table(
    cbind(h[['breaks']][-length(h[['breaks']])],
      h[['breaks']][-1], h[['counts']]),
    file='miga-project.hist', quote=FALSE, sep='\\t',
    col.names=FALSE, row.names=FALSE);
}
" | R --vanilla

# Gzip
gzip -9 -f miga-project.txt

# Finalize
miga date > "miga-project.done"
miga add_result -P "$PROJECT" -r "$SCRIPT" -f
