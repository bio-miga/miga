#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
set -e
SCRIPT="ani_distances"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
DIR="$PROJECT/data/09.distances/03.ani"

# Initialize
miga_start_project_step "$DIR"

# Extract values
function foreach_database_ani {
  local SQL="SELECT seq1, seq2, ani, sd, n, omega from ani;"
  local k=0
  while [[ -n ${DS[$k]} ]] ; do
    echo "$SQL" | sqlite3 "$DIR/${DS[$k]}.db" | tr "\\|" "\\t"
    let k=$k+1
  done
}

function ani_tsv {
  DS=($(miga ls -P "$PROJECT" --ref --no-multi --active))
  echo "a b value sd n omega" | tr " " "\\t"
  foreach_database_ani
}

rm -f "miga-project.txt"
ani_tsv | tee >(wc -l | awk '{print $1-1}' > "miga-project.txt.lno") \
  | gzip -9c > "miga-project.txt.gz"
LNO=$(cat "miga-project.txt.lno")
rm "miga-project.txt.lno"

# R-ify
cat <<R | R --vanilla
file <- gzfile("miga-project.txt.gz")
ani <- read.table(
  file, sep = "\t", header = TRUE, as.is = TRUE, quote = "",
  stringsAsFactors = FALSE, comment.char = "", nrows = $LNO,
  colClasses = c("character", "character",
                 "numeric", "numeric", "integer", "integer")
)
saveRDS(ani, file = "miga-project.rds")
if(sum(ani[, "a"] != ani[, "b"]) > 0) {
  h <- hist(ani[ani[, "a"] != ani[, "b"], "value"], breaks = 100, plot = FALSE)
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
