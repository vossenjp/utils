#!/usr/bin/perl -w
# pivot.pl--Pivot cells (e.g. columns to rows) in a table

# Original Author/date: JP, 2003
# Ported from DOS/Win ~/Pub/util/pivot.pl 2020-04-05 Sun
# $URL: file:///home/SVN/usr_local_bin/pivot.pl $
my $VERSION = '$Id: pivot.pl 2109 2020-04-05 20:02:44Z root $';
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
((my $PROGRAM = $0) =~ s/^.*(\/|\\)//ig); # remove up to last "\" or "/"

# Declare everything to keep -w and use strict happy
my  ( $INFILE, $OUTFILE, $aline, @aline, $header, $header_len, $cell,
  @header, %pivot, $verbose, $delimit_in, $delimit_out, );
our ( $opt_i, $opt_o, , $opt_d, $opt_D, $opt_h, $opt_v, $opt_V, );

use strict;
use warnings;  # Redundant with -w above

use Getopt::Std;         # Use Perl5 built-in program argument handler
getopts('i:o:d:D:hv');   # Define possible args.

Usage(0)   if $opt_h;
Version(0) if $opt_V;
$verbose = $opt_v || 0;

# Set defaults, use better names and other variables
$delimit_in  = $opt_d || "\t";
$delimit_out = $opt_D || "\t";

##########################################################################
# Main

if (! $opt_i) { $opt_i = "-"; } # If no input file specified, use STDIN
if (! $opt_o) { $opt_o = "-"; } # If no output file specified, use STDOUT

open ($INFILE, "$opt_i")   or die ("$PROGRAM: error opening '$opt_i' for input: $!\n");
open ($OUTFILE, ">$opt_o") or die ("$PROGRAM: error opening '$opt_o' for output: $!\n");

if ($verbose) { print STDERR ("\nPivoting '$opt_i' ($delimit_in) to '$opt_i' ($delimit_out)\n"); }

# Get the first line (i.e. the header line)
$aline = <$INFILE>;
chomp($aline);
@header = split(/$delimit_in/, $aline);
$header_len = @header+0;

# Process the rest of the file
while ($aline = <$INFILE>) {
    chomp($aline);

    my @arecord = split(/$delimit_in/, $aline);
    my $record_len = @arecord+0;
    if ($record_len > $header_len) {
        warn ("$PROGRAM warning: omitting cell(s) without header '@arecord[$header_len..$record_len]'!\n");
        warn ("There is a row longer than the header row--add header(s) as needed.\n");
    } # end of row length sanity check

    my $idx = 0;  # Set a record index (should have used a push here)
    foreach my $cell (@header) {  # Go down the list of "headers" (now lines)
        $pivot{$cell} .= "$arecord[$idx]$delimit_out";  # and build the output
        $idx++;
    } # end of this line
} # end of the input


# Write the output
foreach $cell (@header) {  # Go down the list of "headers" (now lines)
    $pivot{$cell} =~ s/$delimit_out$//;    # Remove trailing delimiter
    print $OUTFILE ("$cell$delimit_out$pivot{$cell}\n");
} # end of foreach output

if ($verbose) { print STDERR ("\n\a$PROGRAM finished in ",time()-$^T," seconds.\n"); }

# End of main
##########################################################################

# Subroutines
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Emit usage information
# Returns:  nothing, just exits
sub usage {
    # Unlike sh, Perl does not have a built in way to skip leading
    # TABs (but not spaces) to allow indenting in HERE docs  So we cheat.
    ($USAGE = sprintf <<"EoN") =~ s/^\t//gm;
		Usage: $PROGRAM [OPTIONS] (-i [FILE]) (-o [FILE]) (-v)

		   -i {infile}    = Use infile as the input file, otherwise use STDIN.
		   -o {outfile}   = Use outfile as the output file, otherwise use STDOUT.
		   -d {delimiter} = Input delimiter (TAB is default)
		   -D {delimiter} = Output delimiter (TAB is default)
		   -v = Verbose
		   -V = Version

		Pivot cells (e.g. columns to rows) in a table:

		   Columns to rows  {-- same as --}  Rows to Columns
		H1 H2 H3  -->  H1 A1 B1 C1     L1 A1 B1 C1  -->  L1 L2 L3
		A1 A2 A3  -->  H2 A2 B2 C2     L2 A2 B2 C2  -->  A1 A2 A3
		B1 B2 B3  -->  H3 A3 B3 C3     L3 A3 B3 C3  -->  B1 B2 B3
		C1 C2 C3  --/                               --\  C1 C2 C3

		The first row (headers) must be >= the longest row in the data. Any row
		longer than the first row will be truncated and a warning will be emitted.
EoN
    die ("\n");
} # end of usage


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Emit version and other information
# Returns:  nothing, just exits
sub Version {
    # Called like: Version ({exit code})
    my $exit_code = $_[0] || 1; # Default of 1 if exit code not specified
    print "$PROGRAM $VERSION\n";
    exit $exit_code; # exit with the specified error code
} # end of sub Version
