#!/bin/bash

# take in thresholds for ppos and qcovs
# creates folder called pposXqcovsY and subfolders byQuery, temp_files, muscle
# does selfblastp -> separate by query -> filter by parameters 
# creates csv file in root for visualization of variation of parameters
# goes into muscle and compares all the files, deleting duplicates along the way
# create a log of what was the same, count number of unique groups
# go into temp_files and get csv of size of group for protein

# Author: Jessica Ma
# Date: February 21st, 2018

ppos=$1
qcovs=$2
BLAST=/projects/spruceup_scratch/psitchensis/Q903/annotation/amp/alignment/MSAs/selfblast.blastp
DB=/projects/spruceup_scratch/psitchensis/Q903/annotation/amp/alignment/MSAs/db.fa

#ROOT=/projects/spruceup_scratch/psitchensis/Q903/annotation/amp/alignment/MSAs
ROOT=/home/jma/Documents
CORE=$ROOT/ppos"$ppos"-qcovs"$qcovs"
BYQ=$CORE/byQuery
TEMP=$CORE/temp_files
MUSC=$CORE/muscle
mkdir $CORE $BYQ $TEMP $MUSC

# separate blast file by query protein 
cd $BYQ
awk '{print>$1}' $BLAST

# make CSV to see variation wrt ppos/qcovs parameters
for f in $BYQ/*
do 
    fname=`basename $f`
    awk '$NF>"$qcovs" && $(NF-1)>"$ppos" {print $2}' $f | sort | uniq > $TEMP/$fname
    wc -l $TEMP/$fname >> $CORE/ppos"$ppos"-qcovs"$qcovs"-results.txt
    
done 

# checking for duplicates, deleting duplicates, creating log file
# found this script on unix.stackexchange #367749 and made little adjustments
declare -A filecksums

for f in $TEMP/*
do
    # Files only (also no symlinks)
    [[ -f "$f" ]] && [[ ! -h "$f" ]] || continue

    # Generate the checksum
    cksum=$(cksum <"$f" | tr ' ' _)

    # Have we already got this one?
    if [[ -n "${filecksums[$cksum]}" ]] && [[ "${filecksums[$cksum]}" != "$f" ]]
    then
        echo `basename $f`", "`basename ${filecksums[$cksum]}` >> $CORE/duplicates.txt
        rm -f "$f"
    else
        filecksums[$cksum]="$f"
    fi

done

# identify and delete singletons
for f in $TEMP/*
do 
    a=`cat "$f" | wc -l`   
    if [ "$a" -eq 1 ]
    then
       echo `basename $f` >> $CORE/singletons.txt
       rm -f "$f"
    fi

done

# make FASTA files from unique groupings and run muscle on them
for f in $TEMP/*
do
    fname=`basename $f`
    seqtk subseq $DB $TEMP/$fname | muscle -out $MUSC/$fname-msa.fa
done
exit
