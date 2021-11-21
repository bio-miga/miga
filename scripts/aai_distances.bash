#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
set -e
SCRIPT="aai_distances"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
DIR="$PROJECT/data/09.distances/02.aai"

# Initialize
miga_start_project_step "$DIR"

# Extract values
rm -f miga-project.txt
SQL="SELECT seq1, seq2, aai, sd, n, omega from aai;"
DS=$(miga ls -P "$PROJECT" --ref --no-multi --active)
(
  echo "a b value sd n omega" | tr " " "\\t"
  for i in $DS ; do
    echo "$SQL" | sqlite3 "$DIR/$i.db" | tr "\\|" "\\t"
  done
) | gzip -9c > miga-project.txt.gz

# R-ify
cat <<R | R --vanilla
file <- gzfile("miga-project.txt.gz")
aai <- read.table(file, sep = "\t", header = TRUE, as.is = TRUE)
saveRDS(aai, file = "miga-project.rds")
if(sum(aai[, "a"] != aai[, "b"]) > 0) {
  h <- hist(aai[aai[, "a"] != aai[, "b"], "value"], breaks = 100, plot = FALSE)
  len <- length(h[["breaks"]])
  write.table(
    cbind(h[["breaks"]][-len], h[["breaks"]][-1], h[["counts"]]),
    file = "miga-project.hist", quote = FALSE, sep = "\t",
    col.names = FALSE, row.names = FALSE
  )
}
R

# Finalize
miga_end_project_step "$DIR"
