#!/usr/bin/env python3
# pivot-key-values.py--Pivot a key and a comma delimited value column into a matrix
# See also: mergel.pl, pivot.pl, pivot-by-date.pl, pivot-key-value.pl
# Original Author/date: JP, 2025-02-02, and `ollama run qwen2.5-coder:7b`
# $URL: file:///home/SVN/usr_local_bin/pivot-key-values.py $
# $VERSION$'
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# Pivot:
# Key\tvalue1, value2, value3   |    To matrix (with -Z):
# K1 V1, V2, V3                 | V1 K1, K2, K4
# K2 V4, V5, V1                 | V2 K1, K3, K4
# K3 V2, V3, V4                 | V3 K1, K3, K5
# K4 V5, V1, V2                 | V4 K2, K3, K5
# K5 V3, V4, V5                 | V5 K2, K4, K5

import argparse
import re
import sys

pivot_dict = {}


def parse_args(args=sys.argv[1:]):
    '''Parse CLI arguments'''

    parser = argparse.ArgumentParser(add_help=True,
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        description='Pivot a key and delimited value column into a matrix')

    parser.add_argument('-i', '--input', type=argparse.FileType('r'),
                        nargs='?', default=sys.stdin,
                        help='Optional input file')

    parser.add_argument('-o', '--output', type=argparse.FileType('w'),
                        nargs='?', default=sys.stdout,
                        help='Optional output file')

    parser.add_argument('-k', '--key_delimiter', default='\t',
                        help='Optional key > value delimiter')

    parser.add_argument('-d', '--delimiter', default=',',
                        help='Optional value list delimiter')

    parser.add_argument('-Z', '--no-zim', action='store_true',
                        help='Do NOT use Zim output format \t* **Key**\t')

    return parser.parse_args(args)


def Read_Input(input_file, key_delimiter, delimiter):
    '''Read input like:   * Key\tValue1, Value2, Value3'''

    try:
        with input_file as input_file_handle:
            for lineno, record in enumerate(input_file_handle, start=1):
                record = record.strip()
                record = re.sub(f'\*|\?|\(|\)', '', record)  # Remove: *?()
                record = re.sub(f' +', ' ', record)          # Squash spaces
                try:  # SKIP blank lines or lines without a key_delimiter
                    key, value_list = record.split(key_delimiter, 1)
                except:
                    continue
                key = key.strip()
                value_list = value_list.strip()
                values = value_list.split(delimiter)

                # Pivot the values into keys!
                for value in values:
                    value = value.strip()
                    if not value:
                        value = 'MISSING'
                    if value not in pivot_dict:
                        pivot_dict[value] = []
                    pivot_dict[value].append(key)

    except FileNotFoundError:
        print(f"ABORTED: The input file '{input_file.name}' was not found.")
    except Exception as error:
        print(f"ABORTED: Error on line {lineno} in {input_file.name}: {error}")

    return pivot_dict


def Write_Output(pivot_dict, output_file, key_delimiter, delimiter, no_zim):
    '''Write output, by default in Zim bullet list format with new key in **bold**'''

    with output_file as of:
        for key in sorted(pivot_dict):
            if no_zim:
                out_key = f"{key}{key_delimiter}"
            else:
                out_key = f"\t* **{key}**\t"
                delimiter = ','

            # New key, so no newline (end='')
            print(out_key, end='', file=of)
            # New value list, * = Plain text, no brackets
            print(*sorted(pivot_dict[key]), sep=f'{delimiter} ', file=of)


##########################################################################
def main():
    args = parse_args()
    #print(args)

    pivot_dict = Read_Input(args.input, args.key_delimiter, args.delimiter)
    Write_Output(pivot_dict, args.output, args.key_delimiter, args.delimiter, args.no_zim)

if __name__ == '__main__':
    main()
