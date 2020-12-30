#!/usr/bin/perl
# DoMath.pl--Perform math operations on arbitrary lines of numerical input

# $Id: domath.pl 679 2005-01-09 08:11:16Z jp $
# $URL$

# ToDo:	Add more options for calculation?
#	Add precision and format specifications (e.g. printf)?
#	Handle percents better?

$ver = '$Version: 1.5 $'; # JP Vossen <jp@jpsdomain.org>
##########################################################################
(($myname = $0) =~ s/^.*(\/|\\)//ig); # remove up to last "\" or "/"
$Greeting =  ("$myname $ver Copyright 2002-2004 JP Vossen (http://www.jpsdomain.org/)\n");
$Greeting .= ("    Licensed under the GNU GENERAL PUBLIC LICENSE:\n");
$Greeting .= ("    See http://www.gnu.org/copyleft/gpl.html for full text and details.\n"); # Version and copyright info

if ("@ARGV" =~ /^\?|^-h$|^--help$/) {
    print STDERR ("\n$Greeting\n");
    print STDERR <<"EoN";    # Usage notes
Usage: $myname [-i {infile}] [-o {outfile}] (options) [-q]

    -i {infile}  = Use infile as the input file, otherwise use STDIN.
    -o {outfile} = Use outfile as the output file, otherwise use STDOUT.
    -d {desc}    = Display a description of the output.
    -s = Display the Sum of the input.
    -a = Display the Average of the input.
    -c = Display a Count of the lines of input.
    -p = DON'T remove all Punctuation (actually, anything other than 0-9)
         before processing.
    -q = Only display the answer.
    -D = Print debug messages to STDERR.

Perform math operations on arbitrary lines of numerical input. Input is
assumed to be just numbers--very little sanity checking is performed!
EoN
    die ("\n");
} # end of usage

use Getopt::Std;          # Use Perl5 built-in program argument handler
getopts('i:o:d:acpqDs');  # Define possible args.

if (! $opt_i) { $opt_i = "-"; }  # If no input file specified, use STDIN
if (! $opt_o) { $opt_o = "-"; }  # If no output file specified, use STDOUT

open (INFILE, "$opt_i")   or die ("$myname: error opening $opt_i $!\n");
open (OUTFILE, ">$opt_o") or die ("$myname: error opening $opt_o $!\n");

if (! $opt_q) { print STDERR ("\n$Greeting\n"); }

# Interpolate opt_d  and use it for the descriptiom if it exists.
$desc = eval "qq{$opt_d}" || '';

while (<INFILE>) {

    if (! $opt_p) { tr/[0-9].//cd; }  # Remove everything BUT numbers

    $count++   if m/\d/;  # Count any line that has a digit in it
    $total+=$_ if m/\d/;  # Add to the total any line that has a digit in it

    $opt_D and warn ("$myname: Count\t$count\tTotal\t$total\t~$_~\n");
} # end of while input


# Did NOT use an if/else so this way more than one option can be combined!

if ($opt_s) {
    if ($opt_q) {
        print ("${desc}$total\n");
    } else {
        print ("${desc}Sum:\t$total\n");
    } # end of quiet
} # end of sum


if ($opt_a) {
    $average=$total/$count;
    if ($opt_q) {
        print ("${desc}$average\n");
    } else {
        print ("${desc}Average:\t$average\n");
    } # end of quiet
} # end of sum


if ($opt_c) {
    if ($opt_q) {
        print ("${desc}$count\n");
    } else {
        print ("${desc}Line Count:\t$count\n");
    } # end of quiet
} # end of sum


if (! $opt_q) { print STDERR ("\n\a$myname finished in ",time()-$^T," seconds.\n"); }

