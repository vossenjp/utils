#!/usr/bin/perl
# pivot-key-value.pl--Pivot a key and a value column into a matrix
# See also: mergel.pl, pivot.pl, pivot-by-date.pl
# Original Author/date: JP, 2023-03-23
# $URL: file:///home/SVN/usr_local_bin/pivot-key-value.pl $
my $VERSION = '$Id: pivot-key-value.pl 2222 2024-01-22 00:40:08Z root $';
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
((my $PROGRAM = $0) =~ s/^.*(\/|\\)//ig); # remove up to last "\" or "/"

# Declare everything to keep -w and use strict happy
my  ( $INFILE, $OUTFILE, $aline, $verbose, $delimit_in, $delimit_out,
  %seen_keys, %seen_values, %hash, );
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

# Process the file
while ($aline = <$INFILE>) {
    chomp($aline);

    my @arecord = split(/$delimit_in/, $aline);
    my $record_len = @arecord+0;
    if ($record_len != 2) {
        warn ("$PROGRAM warning: omitting line that is not 2 columns: ~$aline~\n");
    } # end of row length sanity check

    $seen_keys{$arecord[0]} ++;          # Key
    $seen_values{$arecord[1]} ++;        # Value
    $hash{$arecord[0]}{$arecord[1]} ++;  # Key = Value
} # end of the input


# Write the header of all the values we saw
print $OUTFILE ("Key$delimit_out");
foreach my $value (sort keys %seen_values) {  # Go down the list of values
    print $OUTFILE ("$value$delimit_out");
}
print $OUTFILE ("\n");

# Write the output of all the keys, and the associated values, if any
foreach my $key (sort keys %seen_keys) {  # Go down the list of keys
    print $OUTFILE ("$key$delimit_out");
    foreach my $value (sort keys %seen_values) {  # Go down the list of values
        if (defined $hash{$key}{$value}) {
            print $OUTFILE ("$value$delimit_out");  # Value
        } else {
            print $OUTFILE ("$delimit_out");        # NULL placeholder!
        }
    }
    print $OUTFILE ("\n");
}

if ($verbose) { print STDERR ("\n\a$PROGRAM finished in ",time()-$^T," seconds.\n"); }

# End of main
##########################################################################


# Subroutines
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Emit usage information
# Returns:  nothing, just exits
sub Usage {
    my $exit_code = $_[0] || 1; # Default of 1 if exit code not specified

    # Unlike sh, Perl does not have a built in way to skip leading
    # TABs (but not spaces) to allow indenting in HERE docs  So we cheat.
    (my $usage = sprintf <<"EoN") =~ s/^\t+//gm;
		Usage: $PROGRAM [OPTIONS] (-i [FILE]) (-o [FILE]) (-v)

		   -i {infile}    = Use infile as the input file, otherwise use STDIN.
		   -o {outfile}   = Use outfile as the output file, otherwise use STDOUT.
		   -d {delimiter} = Input delimiter (TAB is default)
		   -D {delimiter} = Output delimiter (TAB is default)
		   -v = Verbose
		   -V = Version

		Pivot a key and a value column into a matrix:
		    Key:Value   |    To matrix:
		    K1 V1       |    Key V1 V2 V3 V4 V5
		    K2 V2       |    K1  V1       V4
		    K3 V3       |    K2     V2
		    K1 V4       |    K3        V3    V5
		    K3 V5       |

		Only 2 columns and no headers are permitted in the input file.
EoN
    print "$usage\n";
    exit $exit_code; # exit with the specified error code
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
