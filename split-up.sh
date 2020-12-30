#!/bin/bash -
# split-up.sh--Split up a file by writing alternating lines to different files

# $Id: split-up.sh 1378 2007-09-06 18:17:39Z root $
# $URL: file:///home/SVN/usr_local_bin/split-up.sh $

if [ $# -lt 3 -o "$1" = '-h' -o "$1" = '--help' ]; then
    printf "%b" "\nUsage:\t$0 <input> <output1> <output2> (... <outputN>)\n"
    printf "%b" "\nDump sequential lines from <input> into <output?> files, e.g.:\n"
    printf "%b" "\nsplit-up.sh sample sample.1 sample.2 sample.3\n"
    printf "%b" "\tline 1 > sample.1\n"
    printf "%b" "\tline 2 > sample.2\n"
    printf "%b" "\tline 3 > sample.3\n"
    printf "%b" "\tline 4 > sample.1\n"
    printf "%b" "\tline 5 > sample.2\n"
    printf "%b" "\tline 6 > sample.3\n"
    exit 0
fi

input_file=$1
shift

output_file_array=($*)      # Zero-based
num_output_files=$(( $# ))  # Number of output files in array
index=0

while read line; do
    echo $line >> ${output_file_array[index]}
    (( index ++ ))
    [ $index -ge $num_output_files ] && index=0
done < $input_file
