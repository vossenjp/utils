#!/usr/bin/perl
# Sample.pl--Sample a log file to create a smaller file.

# $Id: sample.pl 1808 2012-03-09 22:17:27Z root $
# $URL: file:///home/SVN/util/sample.pl $

# See also _Classic Shell Scripting_ page 241 for an awk one-liner:
# 	awk 'rand() < 0.05' file(s)

$ver = '$Version: 1.1 $'; # JP Vossen <jp@jpsdomain.org>
##########################################################################
(($myname = $0) =~ s/^.*(\/|\\)//ig); # remove up to last "\" or "/"
$Greeting  = ("$myname $ver Copyright 2005-2012 JP Vossen (http://www.jpsdomain.org/)\n");
$Greeting .= ("    Licensed under the GNU GENERAL PUBLIC LICENSE:\n");
$Greeting .= ("    See http://www.gnu.org/copyleft/gpl.html for full text and details.\n");


if ("@ARGV" =~ /^\?|^-h$|^--help$/) {
    print STDERR ("\n$Greeting\n");
    print STDERR <<"EoN";    # Usage notes
Usage: $myname [OPTIONS] (-i [FILE]) (-o [FILE] | -W) (-q)

   -i {infile}   = Use infile as the input file, otherwise use STDIN.
   -o {outfile}  = Use outfile as the output file, otherwise use STDOUT.
   -l {lines}    = Output every N'th line (N must be 2 or more).
   -p {percent}  = Output approximately N percent of the file (N = 1-50%). *
   -q = Be quiet about it.
   -A = Allow small files (i.e. disable small file check).
   -D {level} = Print debug messages to STDERR (level = 1-3).

Sample a log file to create a smaller file that is easier to download, analyze
etc.  You may get odd results if the input file is too small and your criteria
too large, but the whole purpose is to make LARGE files smaller, so this should
not be a problem. This script is line (as opposed to size or character)
oriented.

* -p estimates the -l value needed to return the specified percent of the file.
In order to avoid processing the file twice, -p calculates the number of
lines to sample based on file size. As it samples, it re-calculates the
average line length automatically, and adjusts (-l) as needed. Also, since the
smallest possible -l is 2 (sample every other line), the largest percent of the
file that may be returned is 50%.
EoN
    die ("\n");
} # end of usage

use Getopt::Std; # Use Perl5 built-in program argument handler
getopts('i:o:l:p:qAD:'); # Define possible args.

# Use better names for parameters
$Sample_Limit  = sprintf("%.0f", $opt_l); # Get integer number of lines to skip if -l
$Percent_Limit = $opt_p/100;              # Get the percent if using -p

if (! $opt_i) { $opt_i = "-"; } # If no input file specified, use STDIN
if (! $opt_o) { $opt_o = "-"; } # If no output file specified, use STDOUT

open (INFILE,   "$opt_i") or die ("$myname: error opening '$opt_i' for input: $!\n");
open (OUTFILE, ">$opt_o") or die ("$myname: error opening '$opt_o' for output: $!\n");
binmode (INFILE);  # Put input/output files into binmode to not mess up line...
binmode (OUTFILE); # ...termination so we can account for that in calculations.  Sigh.

if (! $opt_q) { print STDERR ("\n$Greeting\n"); }

# Sanity checks
if (! (defined ($opt_l) or  defined ($opt_p))) { die ("$myname: must use one of -l or -p!\n"); }
if (   defined ($opt_l) and defined ($opt_p))  { die ("$myname: can't use both -l and -p at the same time!\n"); }
if (defined($opt_l) and ($opt_l < 2))          { die ("$myname: -l must be greater than 2!\n"); }
if (defined($opt_p) and ($opt_p < 1 or $opt_p > 50)) { die ("$myname: -p must be in the range 1 to 50!\n"); }
if (defined($opt_D) and ($opt_D < 1 or $opt_D > 3))  { die ("$myname: -D must be in the range 1 to 3!\n"); }
@file_stat = stat(INFILE);  # Get input file stats
$file_size = $file_stat[7] || '8192'; # Get file size OR make something up (e.g. if STDIN))
if (! defined($opt_A) and $file_size < 1000)  { die ("$myname: $opt_i < 1,000 bytes, makes no sense to run!\n"); }


if ($opt_p) {                                      # Percent sampling mode
    $Sample_Limit = 10;   # Bypass 10 lines to miss headers which are probably atypical lengths
    if ($opt_D > 0) { warn ("$myname(1): [-p mode] File bytes: ", &commify($file_size), "\tPercent limit: $Percent_Limit\n"); }
} else {
    if ($opt_D > 0) { warn ("$myname(1): [-l mode] File bytes: ", &commify($file_size), "\tOutput every '$Sample_Limit' lines\n"); }
} # end of -p mode


# Main loop
while ($aline = <INFILE>) {
    $line++;        # Series line number (reset once a line is sampled)
    $total_lines++; # Total lines

    if ($line >= $Sample_Limit) {  # We've reached our sample limit
        print OUTFILE ("$aline");  # Print out the sample line
        $line=0;                   # Reset the sample series line number
        $printed++;                # Count lines printed

        if ($opt_p) {                              # Percent sampling mode
            # Note we only-recalc inside the sample limit block to reduce the
            # amount of math we have to do so we run a little faster. So we only
            # get the average length of lines we've sampled. Hopefully we have a
            # good sample population, so that should more or less work out.
            $total_length += length ($aline);       # Total line length
            $average_line = $total_length/$printed; # Find average line len.
            $est_lines = $file_size/$average_line;  # Estimate # of lines based on file size

            # Re-calc the (-l) limit as an integer. '$est_lines*$Percent_Limit'
            # gives us the approximate number of lines needed, dividing that
            # into $est_lines gives us the approximate number of lines to SKIP (-l)!
            $Sample_Limit = sprintf("%.0f", $est_lines/($est_lines*$Percent_Limit));

            if ($opt_D > 1) { warn ("$myname(2): Tl len: $total_length\tAve: $average_line\tEst. lines: $est_lines\n"); }
        } # end of -p mode
    } # end of if skip block
    if ($opt_D > 2) { warn ("$myname(3): Tl lines: $total_lines\tPrinted: $printed\tSeries line: $line\tLimit: $Sample_Limit\n"); }
} # end of while input (main loop)
if (defined($opt_p) and $opt_D > 0) { warn ("$myname(1): Final: Tl len: $total_length\tAve: $average_line\tEst. lines: $est_lines\n"); }

if (! $opt_q) { print STDERR ("\n\a$myname finished in ",time()-$^T," seconds and printed ", &commify($printed), " lines out of ", &commify ($total_lines), ".\n"); }
##########################################################################
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub commify {

    # From page 64, 2.17 of _Perl_Cookbook_ by Christiansen & Torkington
    # Copyright 1998 O'Reilly & Associates.

    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;

} # end of sub commify
