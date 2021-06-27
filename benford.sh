#!/bin/bash -
# benford.sh--Write a Benford's Law histogram from input (in pure bash)
# Inspired by: _bash Cookbook2_ (Carl's code)
#    pg 194, 7.15 Counting String Values with bash
#    pg 198, 7.17 An Easy Histogram with bash
# Adapted: JP, 2021-06-27
# $URL: file:///home/SVN/usr_local_bin/benford.sh $
ID='$Id: benford.sh 2169 2021-06-27 19:19:02Z root $'
#_________________________________________________________________________
PROGRAM=${0##*/}  # bash version of `basename`

# Simple help and usage
if [ $# -gt 0 -o "$1" = '-h' -o "$1" = '--help' ]; then
    cat <<-EoN
	benford.sh--Write a Benford's Law histogram from input
	    Usage: <input> | $PROGRAM
	e.g.
	    $PROGRAM < file
	    cat file | $PROGRAM
	    grep 'something | $PROGRAM
	    ls -l | $PROGRAM
	EoN
    exit 0
fi

# See https://en.wikipedia.org/wiki/Benford%27s_law
# bash is integer only!
# 0 is not used, but arrays start there so keep that as a spacer
#         0    1      2      3       4      5      6      7      8      9
# Really (0, 0.301, 0.176, 0.125, 0.097, 0.079, 0.067, 0.058, 0.051, 0.046)
benford+=(0    30     17     12      9      7      6      5      5      4)

# Initialize an empty input array
input+=(  0    0      0      0       0      0      0      0      0      0)

while read line; do                       # Read STDIN
    for word in $line; do                 # For each space-delimited "word"
        if [[ "$word" =~ ^[1-9] ]]; then  # If the first char is a number (not 0)
            first_digit="${word:0:1}"       # Grab that first digit
            (( input[first_digit]++ ))      # Increment the per-digit counter
            (( total_records++ ))           # Increment the total records
        fi
    done
done

# Print header
echo -e "\nBenford's Law Histogram (# = Benford, * = input)\n"

# Print histogram
for digit in {1..9}; do

    # Benford's Law (#)
    printf "%-2s [%2d]:" $digit ${benford[$digit]}  # 1  [30]:
    for ((i=0; i<benford[$digit]; i++)) {           # Draw the bar
        printf "#"
    }
    printf "\n"

    # Input data (*)
    if [ "${input[$digit]}" == 0 ]; then
        # Zero occurrences...can't divide zero by total below
        digit_percent=0
    else
        # Figure out the PERCENT of digit occurrence (INTEGER ONLY)!
        digit_percent=$(( 100 * ${input[$digit]} / $total_records))
    fi
    printf "   [%2d]:" ${input[$digit]}             #    [%n]:
    for ((i=0; i<digit_percent; i++)) {             # Draw the bar
        printf "*"
    }
    printf "\n"

done

echo -e "\nTotal input records: $total_records"
