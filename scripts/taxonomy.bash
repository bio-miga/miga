#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES, $DATASET
set -e
SCRIPT="taxonomy"
# shellcheck source=scripts/miga.bash
. "$MIGA/scripts/miga.bash" || exit 1
DIR="$PROJECT/data/09.distances/05.taxonomy"
[[ -d "$DIR" ]] || mkdir -p "$DIR"
cd "$DIR"

# Initialize
miga date > "$DATASET.start"

# Run
ruby -I "$MIGA/lib" \
      "$MIGA/utils/distances.rb" "$PROJECT" "$DATASET" run_taxonomy=1

# Finalize
fastaai=no
aai=no
ani=no
blast=no
blat=no
diamond=no
fastani=no
REF_PROJECT=$(miga option -P "$PROJECT" -k ref_project)
if [[ -S "$REF_PROJECT" ]] ; then
  case $(miga option -P "$REF_PROJECT" -k haai_p) in
    fastaai)
      fastaai=yes
      ;;
    diamond)
      diamond=yes
      aai=yes
      ;;
    blast)
      blast=yes
      aai=yes
      ;;
  esac

  case $(miga option -P "$REF_PROJECT" -k aai_p) in
    diamond)
      diamond=yes
      aai=yes
      ;;
    blast)
      blast=yes
      aai=yes
      ;;
  esac

  case $(miga option -P "$REF_PROJECT" -k ani_p) in
    blast)
      blast=yes
      ani=yes
      ;;
    blat)
      blat=yes
      ani=yes
    ;;
  fastani)
    fastani=yes
    ;;
  esac
fi

miga date > "${DATASET}.done"
cat <<VERSIONS \
  | miga add_result -P "$PROJECT" -D "$DATASET" -r "$SCRIPT" -f --stdin-versions
=> MiGA
$(miga --version)
$(
  if [[ "$fastaai" == "yes" ]] ; then
    echo "=> FastAAI"
    fastaai version 2>&1 | perl -pe 's/.*=//'
  fi
)
$(
  if [[ "$fastani" == "yes" ]] ; then
    echo "=> FastANI"
    fastANI --version 2>&1 | grep . | perl -pe 's/^version //'
  fi
)
$(
  if [[ "$aai" == "yes" ]] ; then
    echo "=> Enveomics Collection: aai.rb"
    aai.rb --version 2>&1 | perl -pe 's/.*: //'
  fi
)
$(
  if [[ "$ani" == "yes" ]] ; then
    echo "=> Enveomics Collection: ani.rb"
    ani.rb --version 2>&1 | perl -pe 's/.*: //'
  fi
)
$(
  if [[ "$blast" == "yes" ]] ; then
    echo "=> NCBI BLAST+"
    blastp -version 2>&1 | tail -n 1 | perl -pe 's/.*: blast //'
  fi
)
$(
  if [[ "$blat" == "yes" ]] ; then
    echo "=> BLAT"
    blat 2>&1 | head -n 1 | perl -pe 's/.* v\. //' | perl -pe 's/ fast .*//'
  fi
)
$(
  if [[ "$diamond" == "yes" ]] ; then
    echo "=> Diamond"
    diamond --version 2>&1 | perl -pe 's/^diamond version //'
  fi
)
VERSIONS

