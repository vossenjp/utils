#!/bin/bash -
# Display a "ruler" across the screen
# Partly from https://forums.linuxmint.com/viewtopic.php?p=527794&sid=a04b71fdb734b5768224a70f0e1e6e10#p527794
# 2020-02-20, merged existing and above into better script

# Example: ruler.sh ; mount | grep 'none' | column -t

if [ -n "$1" ]; then
    COLUMNS=$1                 # Arbitrary width
else
    COLUMNS=$(tput cols)       # Screen column width
fi
COLUMNS10=$((COLUMNS/10))      # Width divided by 10

# Tens separators
for (( x=1; x<=COLUMNS10; x++ )); do
    printf '%10d' $x
done
echo ''  # Newline

# Units
for (( i=1 ; i <= COLUMNS ; i++ )); do
    printf "%d" $((i % 10))
done
echo ''  # Newline
