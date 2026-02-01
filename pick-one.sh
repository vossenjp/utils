#!/bin/bash
# pick-one.sh--Randomly choose from a list of options
# JP, 2025-06-30 Mon

if [ $# -lt 2 -o "$1" = '-h' -o "$1" = '--help' ]; then
    echo "Usage: $0 'Choice 1' 'Choice 2' ('Choice 3' ... 'Choice N')"
    exit 1
fi

# Random index based on how many arguments
random_index=$(( RANDOM % $# + 1 ))

# Choose the $N'th argument
chosen=$(eval echo "\$$random_index")

# Display it
echo "Selected ($random_index): $chosen"
