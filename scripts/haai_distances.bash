#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
set -e
SCRIPT="haai_distances"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
cd "$PROJECT/data/09.distances/01.haai"

# Initialize
miga date > "miga-project.start"

# Cleanup databases
ruby -I "$MIGA/lib" "$MIGA/utils/cleanup-databases.rb" "$PROJECT" "$CORES"

# Run hAAI
echo -n "" > miga-project.log
DS=$(miga ls -P "$PROJECT" --ref --no-multi --active)

# Extract values
echo "metric a b value sd n omega" | tr " " "\\t" >miga-project.txt
for i in $DS ; do
  echo "SELECT 'hAAI', seq1, seq2, aai, sd, n, omega from aai ;" \
    | sqlite3 "$i.db" | tr "\\|" "\\t" >>miga-project.txt
  echo "$i" >> miga-project.log
done

# R-ify
echo "
haai <- read.table('miga-project.txt', sep='\\t', h=T, as.is=TRUE);
save(haai, file='miga-project.Rdata');
if(sum(haai[,'a'] != haai[,'b']) > 0){
  h <- hist(haai[haai[,'a'] != haai[,'b'], 'value'], breaks=100, plot=FALSE);
  write.table(
    cbind(h[['breaks']][-length(h[['breaks']])],
      h[['breaks']][-1],h[['counts']]),
    file='miga-project.hist', quote=FALSE, sep='\\t',
    col.names=FALSE, row.names=FALSE);
}
" | R --vanilla

# Gzip
gzip -9 -f miga-project.txt

# Finalize
miga date > "miga-project.done"
miga add_result -P "$PROJECT" -r "$SCRIPT" -f
