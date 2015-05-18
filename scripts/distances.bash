#!/bin/bash
# Available variables: $PROJECT, $RUNTYPE, $MIGA, $CORES
source "$MIGA/scripts/miga.bash"
cd "$PROJECT/data/09.distances"

# Initialize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.start"

# Check type of dataset
NOMULTI=$($MIGA/bin/list_datasets -P "$PROJECT" -D "$DATASET" --no-multi | wc -l | awk '{print $1}')
ESS="../07.annotation/01.function/01.essential"
if [[ "$NOMULTI" -eq "1" ]] ; then
   # Create output directories
   [[ -d "01.haai/$DATASET.d" ]] || mkdir "01.haai/$DATASET.d"
   [[ -d "02.aai/$DATASET.d" ]] || mkdir "02.aai/$DATASET.d"
   [[ -d "03.ani/$DATASET.d" ]] || mkdir "03.ani/$DATASET.d"

   # Traverse "nearly-half" of the ref-datasets using first-come-first-served
   for i in $($MIGA/bin/list_datasets -P "$PROJECT" --ref --no-multi) ; do
      # Check if this is done (e.g., in a previous failed iteration)
      [[ -s "02.aai/$DATASET.d/$i.txt" ]] && continue
      
      # Check if the i-th dataset is ready
      [[ -s "$ESS/$i.done" ]] || continue
      
      # Check if the other direction is already running (or done)
      if [[ -e "01.haai/$i.d/$DATASET.txt" ]] ; then
	 cd "01.haai/$DATASET.d/"
	 ln -s "../$i.d/$DATASET.txt" "$i.txt"
	 cd "../../"
	 continue
      fi
      touch "01.haai/$DATASET.d/$i.txt"
      
      # Calculate hAAI:
      aai.rb -1 "$ESS/$DATASET.ess.faa" -2 "$ESS/$i.ess.faa" -t "$CORES" -d 10 -o "01.haai/$DATASET.d/$i.out" -T "01.haai/$DATASET.d/$i.tab" -n 10
      echo "hAAI	$DATASET	$i	$(cat "01.haai/$DATASET.d/$i.tab")" > "01.haai/$DATASET.d/$i.txt"
      HAAI=$(cat "01.haai/$DATASET.d/$i.tab" | awk '{print $1}' )
      if [[ $(perl -MPOSIX -e "print floor $HAAI") -lt 90 ]] ; then
	 # Estimate AAI:
	 AAI=$(perl -e "printf '%.10f', 100-exp(2.435076 + 0.4275193*log(100-$HAAI))")
	 echo "hAAI_AAI	$AAI	NA	NA	NA" > "02.aai/$DATASET.d/$i.txt"
      else
	 # Calculate AAI:
	 aai.rb -1 "../06.cds/$DATASET.faa" -2 "../06.cds/$i.faa" -t "$CORES" -d 10 -o "02.aai/$DATASET.d/$i.out" -T "02.aai/$DATASET.d/$i.tab"
	 echo "AAI	$DATASET	$i	$(cat "02.aai/$DATASET.d/$i.tab")" > "02.aai/$DATASET.d/$i.txt"
	 AAI=$(cat "02.aai/$DATASET.d/$i.tab" | awk '{print $1}')
      fi
      
      if [[ $(perl -MPOSIX -e "print ceil $AAI") -gt 90 ]] ; then
	 # Calculate ANI:
	 ani.rb -1 "../05.assembly/$DATASET.LargeContigs.fna" -2 "../05.assembly/$i.LargeContigs.fna" -t "$CORES" -d 10 -o "03.ani/$DATASET.d/$i.out" -T "03.ani/$DATASET.d/$i.tab"
	 echo "ANI\t$DATASET\t$i\t$(cat "02.aai/$DATASET.d/$i.tab")" > "03.ani/$DATASET.d/$i.txt"
      fi
   done
fi

# Finalize
date "+%Y-%m-%d %H:%M:%S %z" > "$DATASET.done"
$MIGA/bin/add_result -P "$PROJECT" -D "$DATASET" -r distances

