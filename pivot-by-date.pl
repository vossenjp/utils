#!/usr/bin/perl -w
# pivot-by-date.pl--Pivot "Count | Date | Key" columnar data by date and key

# Original Author/date: JP, 2005
# Ported from DOS/Win ~/Pub/util/pivot-by-date.pl 2020-04-05 Sun
# $URL: file:///home/SVN/usr_local_bin/pivot-by-date.pl $
my $VERSION = '$Id: pivot-by-date.pl 2109 2020-04-05 20:02:44Z root $';
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
((my $PROGRAM = $0) =~ s/^.*(\/|\\)//ig); # remove up to last "\" or "/"

# Declare everything to keep -w and use strict happy
my  ($INFILE, $OUTFILE, $aline, $message, %linehash, $ipa, $somevalue, $item,
  $Array, $verbose, %epoch_for, %date_for, );
our ($opt_i, $opt_o, $opt_w, $opt_W, $opt_h, $opt_v, $opt_V, $opt_t, $opt_k, $opt_D);
our (%datehash, %years_months, %daily_total);
my ($epoch, $key, $oldest, $newest, $year_month);
my (@arecord, %data, %datakeys);

use strict;
use POSIX qw(strftime); # Easy date/time printing
use Time::Local;        # timegm
use Getopt::Std;
getopts('i:o:hvVtk:D');

Usage(0)   if $opt_h;
Version(0) if $opt_V;
$verbose = $opt_v || 0;

# Prevent 'Use of uninitialized value in numeric gt' when using -D {level}
$opt_D = 0 if not defined $opt_D;

# Lookup table for months to numbers (Yes, this is nuts and starts from 0)
my %month2num = ('jan' => '0', 'jul' => '6',
                 'feb' => '1', 'aug' => '7',
                 'mar' => '2', 'sep' => '8',
                 'apr' => '3', 'oct' => '9',
                 'may' => '4', 'nov' => '10',
                 'jun' => '5', 'dec' => '11');

##########################################################################
# Main

if (! $opt_i) { $opt_i = "-"; } # If no input file specified, use STDIN
if (! $opt_o) { $opt_o = "-"; } # If no output file specified, use STDOUT

open ($INFILE, "$opt_i")   or die ("$PROGRAM: error opening '$opt_i' for input: $!\n");
open ($OUTFILE, ">$opt_o") or die ("$PROGRAM: error opening '$opt_o' for output: $!\n");

if ($verbose) { print STDERR ("\nPivoting dates from '$opt_i' to '$opt_i'\n"); }

# Set keyname default
my $keyname = $opt_k || '';

# "Prime" the oldest and newest record counters
$oldest = 999999999999999;
$newest = 0;

# Input Record field index
my $i_Count = 0;
my $i_Date  = 1;
my $i_Key   = 2;

while ($aline = <$INFILE>) {
    chomp($aline);
    next if $aline =~ m/^\s*$/; # Skip blank lines
    if ($opt_D) { warn ("\n$PROGRAM: ~$aline~\n"); }

    @arecord = split(/\t/, $aline);
    if (not defined $arecord[$i_Key]) {
        warn ("Record looks odd, skipping ~$aline~\n");
        next;
    }

    $arecord[$i_Count] =~ s/,//;        # Remove commas so math works
    $epoch = date2epoch($arecord[$i_Date]);
    foreach (@arecord) { s/^"|"$//g; }  # Remove leading/trailing quotes
    if ($opt_D) { warn ("$PROGRAM: split 0=~$arecord[0]~\t1=~$arecord[1]~\t2=~$arecord[2]~\n"); }

    $data{$epoch}{$arecord[$i_Key]} += $arecord[$i_Count]; # Total by date and key
    $datakeys{$arecord[$i_Key]}     += $arecord[$i_Count]; # Grand total for key
    $daily_total{$epoch} += $arecord[$i_Count] if $opt_t;  # Grand total by day
    $oldest = $epoch if $epoch < $oldest;  # Find oldest and
    $newest = $epoch if $epoch > $newest;  # newest records in the data set

    if ($opt_D) { warn ("$PROGRAM: epoch=~$epoch~\toldest=~$oldest~\tnewest=~$newest~\n"); }
} # end of while input


# Create a fancy hash of all the possible dates between the oldest and newest records
MakeDateHash($oldest, $newest);


# OK, here is the tricky part!  Building the data structures was easy, but
# now we have to get the data back out in the format that we want.
foreach $year_month (sort keys %years_months) { # For each year and month

    # Print the month's header line
     print $OUTFILE ("\n$keyname");
     foreach $epoch (sort keys %datehash) {
         if ("$datehash{$epoch}{'year'} $datehash{$epoch}{'month'}" eq $year_month) {
             print $OUTFILE ("\t$datehash{$epoch}{'date'}");
         }
    } # end of foreach $epoch
    print $OUTFILE ("\n");

    # Print the data, by key
    foreach $key (sort keys %datakeys) {
        print $OUTFILE ("$key");
        foreach $epoch (sort keys %datehash) {
            if ("$datehash{$epoch}{'year'} $datehash{$epoch}{'month'}" eq $year_month) {
                if (exists ($data{$epoch}{$key})) {
                    print $OUTFILE ("\t$data{$epoch}{$key}");
                } else {
                    print $OUTFILE ("\t");
                } # Need to keep an empty TAB even when count is NULL!!!
            } # end of are we in the current month?
        } # end of foreach $epoch
        print $OUTFILE ("\n");
    } # end of foreach $key

    # Print the daily grand total, if using -t
    if ($opt_t) {
        print $OUTFILE ("Total");
        foreach $epoch (sort keys %datehash) {
            if ("$datehash{$epoch}{'year'} $datehash{$epoch}{'month'}" eq $year_month) {
                if (exists ($daily_total{$epoch})) {
                   print $OUTFILE ("\t$daily_total{$epoch}");
               } else {
                   print $OUTFILE ("\t");
               } # Need to keep an empty TAB even when total is NULL!!!
            } # end of are we in the current month?
        } # end of foreach $epoch
        print $OUTFILE ("\n");
    } # end of daily grand totals
} # end of foreach $year_month of data

# End of main
##########################################################################
if ($verbose) { print STDERR ("\n\a$PROGRAM finished in ",time()-$^T," seconds.\n"); }


# Subroutines
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Emit usage information
# Returns:  nothing, just exits
# Called like: Usage ({exit code})
sub usage {
    my $exit_code = $_[0] || 1; # Default of 1 if exit code not specified

    # Unlike sh, Perl does not have a built in way to skip leading
    # TABs (but not spaces) to allow indenting in HERE docs  So we cheat.
    (my $USAGE = sprintf <<"EoN") =~ s/^\t//gm;
		NAME
		    ${PROGRAM}--Pivot columnar data by date and key

		SYNOPSIS
		    $PROGRAM [OPTIONS] [-i file | -w] [-o file | -W]

		OPTIONS
		    -i = Input file (otherwise STDIN)
		    -o = Output file (otherwise STDOUT)
		    -h = This usage
		    -v = Be verbose
		    -V = Show version, copyright and license information

		    -t = Also output daily totals
		    -k = Text to use for label for key field, otherwise blank
		    -D = Print debug messages to STDERR.

		    Examples:
		        $PROGRAM -i file -o file -k "Some Key"

		DESCRIPTION ($VERSION)
		    From 3 TAB delimited columns of data: Count | Date | Key
		    Output a TAB delimited table for each month of data, by key, then count
		    for each date:
		    e.g. Key | 8/1/2005 | 8/2/2005 | 8/3/2005 | 8/4/2005
		         Foo |    1     |    34    |          |    12

		    All keys are shown for all dates in the range of the oldest to newest
		    record, so gaps are apparent.

		AUTHOR / BUG REPORTS
		    JP Vossen (jp {at} jpsdomain {dot} org)
		    http://www.jpsdomain.org/
EoN

    print STDERR ("$USAGE");  # Print the usage
    exit $exit_code;          # exit with the specified error code
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


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Convert various human-readable dates to epoch seconds
# Returns:  given time in epoch seconds as scalar or failure
# Requires: use Time::Local, and a global %epoch_for for caching;
sub date2epoch {
    @_ == 1 or warn ('Sub usage: $epoch = date2epoch($date_to_convert);');
    my ( $date, ) = @_;
    my ($year, $month, $day, $hour, $minute, $second, $epoch);

    return $epoch_for{$date} if exists $epoch_for{$date};

    if ( $date =~ m/^(\w+)\s+(\d+)\s+(\d{1,2}):(\d{1,2}):(\d{1,2}) (\d{3})/ ) { # Date
        # ALMOST stupid syslog default, except with a year fudged in there!
        # But it's a *Perl* year, so it'd be -1900 except we didn't do that!
        $year   = $6;   # Since we didn't add 1900, don't remove it here
        # NOT $year   = $6 - 1900;    # Don't look at me, Perl does years
        $month  = $month2num{lc($1)}; # and months nuts...
        $day    = $2;
        $hour   = $3;
        $minute = $4;
        $second = $5;

    } elsif ( $date =~ m/(\d{4})-(\d{2})-(\d{2})[\stT_-]*(\d{1,2})?:?(\d{1,2})?:?(\d{1,2})?/ ) { # Date
        # Convert various subsets of ISO8601 to epoch
        $year   = $1 - 1900;  # Don't look at me, Perl does years
        $month  = $2 - 1;     # and months nuts...
        $day    = $3;         # But not days.  Go figure.
        $hour   = $4 || "00"; # Default is...
        $minute = $5 || "00"; # midnight if...
        $second = $6 || "00"; # not specified
    } elsif ($date =~ m!(\d{1,2})/(\d{1,2})/(\d{2,4})[\s_-]*(\d{1,2})?:?(\d{1,2})?:?(\d{1,2})?!) { # Date
        # Not recommended, convert D/M/(CC)YY
        $year   = $3;         # Save for later
        $month  = $1 - 1;
        $day    = $2;
        $hour   = $4 || "00"; # Default is...
        $minute = $5 || "00"; # midnight if...
        $second = $6 || "00"; # not specified
        # Now figure out year
        if ($year =~ m/\d{2}/ and $year < 70) {
            # Convert 2 digit year < 70 to 2000 or later
            $year += 100;
        } elsif ($year =~ m/\d{4}/) {
            # Convert 4 digit year the crazy Perl way
            $year -= 1900;
        } # End of figure out year
    } else {
        warn "I don't know how to convert '$date' to epoch";
        return scalar 0;
    } # end of figure out what we have

    $epoch = timegm($second, $minute, $hour, $day, $month, $year);
    $epoch_for{$date} = $epoch;  # Cache for later...
    return scalar $epoch;
} # end of sub date2epoch


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Convert epoch time into various human readable elements
# Returns:  a hash with keys as below (see qw() in debug),
#           OR a scalar from the named hash key (iso or date)
# Requires: use POSIX qw(strftime), and a global %date_for for caching;
sub epoch2date {
    (@_ == 1 or @_ == 2)
      or warn ('Sub usage: %human = epoch2date($epoch_to_convert, (key to return));');
    my ( $epoch, $key_to_return, ) = @_;
    my %date_hash;

    return $date_for{$epoch} if exists $date_for{$epoch};

    if ($epoch =~ m/^\d{9,10}$/) {

        # Assemble each piece
        ($date_hash{'year'},
         $date_hash{'month'},
         $date_hash{'day'},
         $date_hash{'hour'},
         $date_hash{'minute'},
         $date_hash{'second'},
         $date_hash{'tz'}) = split (/ /, (strftime("%Y %m %d %H %M %S", gmtime($epoch)) . " UTC"));

        # Add some other handy keys
        $date_hash{'iso'} =
            "$date_hash{'year'}-$date_hash{'month'}-$date_hash{'day'} " .
            "$date_hash{'hour'}:$date_hash{'minute'}:$date_hash{'second'} $date_hash{'tz'}";
        $date_hash{'date'} =
            "$date_hash{'year'}-$date_hash{'month'}-$date_hash{'day'}";

        if ($opt_D >= 2) {  # "Undocumented" debug level
            warn "\n$PROGRAM;epoch2date: epoch=~$epoch~:";
            foreach my $item (qw(iso date year month day hour minute second tz)) {
                warn "$item\t$date_hash{$item}\n";
            }
            warn "\n";
        } # end of if debug

        if ($key_to_return) {
            $date_for{$epoch} = $date_hash{$key_to_return};  # Cache for later...
            # Return the requested key
            return scalar $date_hash{$key_to_return};

        } else {
            # Return the entire hash
            return (%date_hash);
        }  # end of figure out what to return, hash or value

    } else {
        warn "I don't know how to convert epoch '$epoch' to a human readable date";
        return scalar 0;
    } # end of figure out what input we have
} # end of sub epoch2date


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Write an array of dates into global array %datehasht
# Called like:  MakeDateHash(<start_date>, <end_date>);
# Returns nothing, but populates global %datehash and %years_months
sub MakeDateHash {

    if (scalar @_ < 2) {
        warn ("$PROGRAM: missing arguments to MakeDateHash!\n");
        return 0;
    }

    my ($start_date, $end_date) = @_;
    if ($start_date > $end_date)     { die ("$PROGRAM: '$start_date' > '$end_date' in MakeDateHash!\n"); }
    if ($start_date !~ m/^\d{9,10}/) { die ("$PROGRAM: start date '$start_date' not epoch format!\n"); }
    if ($end_date   !~ m/^\d{9,10}/) { die ("$PROGRAM: end date '$end_date' not epoch format!\n"); }

    my (%human_date, $epoch);
    if ($opt_D) { warn ("$PROGRAM;MakeDateHash: 1 start_date=~$start_date~\tend_date=~$end_date~\n"); }

#    $start_date = date2epoch($start_date);
#    $end_date   = date2epoch($end_date);
    if ($opt_D) { warn ("$PROGRAM;MakeDateHash: 2 start_date=~$start_date~\tend_date=~$end_date~\n"); }

    # 86400 = the seconds in 1 day, so we build a hash of both epoch and
    # human readable dates
    for ($epoch = $start_date; $epoch <= $end_date; $epoch += 86400) {
        if ($opt_D) { warn ("$PROGRAM;MakeDateHash: handling epoch=~$epoch~\n"); }
        # This is neat: to the existing hash keyed by epoch, add a reference to
        # an anonymous hash, so we can later do things like: $datehash{$epoch}{'date'}
        $datehash{$epoch} = { epoch2date($epoch) };
        $years_months{"$datehash{$epoch}{'year'} $datehash{$epoch}{'month'}"} = 1;
    }
} # end of sub MakeDateHash
