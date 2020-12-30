#!/usr/bin/perl
# DNSLookup.pl--Lookup IPAs and get hostnames

# $Id: DNSlookup.pl 1199 2006-06-13 06:07:12Z root $
# $URL: file:///home/SVN/usr_local_bin/DNSlookup.pl $

my $VERSION   = '$Version: 1.0.0 $';
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
((my $PROGRAM = $0) =~ s/^.*(\/|\\)//ig); # remove up to last "\" or "/"

# Declare everything to keep -w and use strict happy
my  ($INFILE, $OUTFILE, $verbose, @ips, $ipa, $src_ip_packed, $host_name, );
our ($opt_i, $opt_o, $opt_w, $opt_W, $opt_h, $opt_v, $opt_V, $opt_q, );

use strict;
use warnings; # instead of -w in perl > 5.6
use Carp; # Replace warn & die with carp & croak to show a calling stack trace
#use diagnostics; # ONLY use this during development, it slows down run-time!
use Socket;
use Getopt::Std;
getopts('i:o:wWhvVq');

Usage(0)   if $opt_h;
Version(0) if $opt_V;
$verbose = $opt_v || 0;


Open_IO($opt_i, $opt_o); # Open input and outfile files

if ($verbose) { warn ("$PROGRAM version $VERSION\n"); }
##########################################################################
# Main

while (<$INFILE>) {

    chomp;
    @ips = m/(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/gs;

    foreach $ipa (@ips) {
        $src_ip_packed = inet_aton($ipa);       # Get the packed format needed
        $host_name = gethostbyaddr($src_ip_packed, AF_INET); # Look it up
        if (! $host_name) {
            # If we can't find it, mark it as unresolvable
            $host_name = "Unresolvable";
        }
        if ($opt_q) {  # using -q to be quiet and just print hostname (answer)
            print $OUTFILE ("$host_name\n");       # Print JUST the hostname(s)
        } else {
            print $OUTFILE ("$ipa\t$host_name\n"); # Print IPA(s) and Hostname(s)
        } # end of if really quiet
    } # end of process each IPA
} # end of get input

# End of main
##########################################################################
if ($opt_W) { _Send_to_Clipboard(); } # Send output directly into the Clipboard
if ($verbose) { warn ("\n\a$PROGRAM finished in ",time()-$^T," seconds.\n"); }


# Subroutines
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Emit usage information
# Returns:  nothing, just exits
sub Usage {
    # Called like: Usage (<exit code>)
    my $exit_code = $_[0] || 1; # Default of 1 if exit code not specified
    # system "perldoc $0";
    system "pod2usage -verbose 1 $0";
    print ("\nFor complete documentation please see 'perldoc $0'\n");
    exit $exit_code;  # exit with the specified error code
} # end of Usage


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Emit version and other information
# Returns:  nothing, just exits
sub Version {
    # Called like: Version ({exit code})
    my $exit_code = $_[0] || 1; # Default of 1 if exit code not specified
    print ("$PROGRAM $VERSION\n");
    exit $exit_code; # exit with the specified error code
} # end of sub Version


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Open input and output files, STDIN/STDOUT or Windows Clipboard
# Returns:  nothing (but see global $INFILE and $OUTFILE)
sub Open_IO {
    @_ == 2 or carp ('Sub usage: Open_IO($opt_i, $opt_o);');
    my ( $infile, $outfile, ) = @_;

    if (! $infile)  { $infile  = "-"; } # If no input file specified, use STDIN
    if (! $outfile) { $outfile = "-"; } # If no output file specified, use STDOUT

    # Input
    if ($opt_w and ($^O eq "MSWin32")) { # If we're getting input from the Windows Clipboard
        eval "use Win32::Clipboard;";    # Import clipboard but don't die if we're not on Windows
        my $cboard  = Win32::Clipboard::GetText();  # (Have to) Read entire clipboard contents
        $cboard =~ s/\r//g;              # Remove odd CRs ("\r"), if any, the clipboard sticks in
        # Dump CDB into a secure temp file that's automatically deleted when we're finished,
        # then rewind it to the main look can read $INFILE as normal.
        use File::Temp;
        $INFILE = tmpfile() or croak ("$PROGRAM: error creating temp file for -w: $!\n");
        print $INFILE ("$cboard");
        seek($INFILE, 0, 0) or croak ("$PROGRAM: error couldn't rewind temp INPUT file: $!\n");
    } elsif ($opt_w and ($^O ne "MSWin32")) {
        croak ("$PROGRAM: can't use -w on Linux or Unix!  What're you thinking?!?\n");
    } else {
        # Regular old input (prefer 3 argument open if possible)
        if ("$infile" eq '-') {
            open ($INFILE, '<-')           or croak ("$PROGRAM: error opening STDIN for input: $!\n");
        } else {
            open ($INFILE, '<', "$infile") or croak ("$PROGRAM: error opening '$infile' for input: $!\n");
        } # end of if STDIN
    } # end of get input from clipboard

    # Output
    if ($opt_W and ($^O eq "MSWin32")) { # We're sending the output directly into the Clipboard
        eval "use Win32::Clipboard;";    # Import clipboard but don't die if we're not on Windows
        # Use a secure temp file that's automatically deleted when we're finished.
        use File::Temp;
        $OUTFILE = tmpfile() or croak ("$PROGRAM: error creating temp file for -W: $!\n");
    } elsif ($opt_W and ($^O ne "MSWin32")) {
        croak ("$PROGRAM: can't use -W on Linux or Unix!  What're you thinking?!?\n");
    } else {
        # Regular old output (prefer 3 argument open if possible)
        # Note use of indirect file handle (e.g. '$' on $OUTFILE), needed for temp file
        if ("$outfile" eq '-') {
            open ($OUTFILE, '>-')            or croak ("$PROGRAM: error opening STDOUT for output: $!\n");
        } else {
            open ($OUTFILE, '>', "$outfile") or croak ("$PROGRAM: error opening '$outfile' for output: $!\n");
        } # end of if STDOUT
    } # end of if using clipboard
} # end of sub Open_IO


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# We're sending the output directly into the Clipboard [internal utility sub]
# Returns:  nothing
sub _Send_to_Clipboard {
    @_ == 0 or carp ('Sub usage: _Send_to_Clipboard()');
    seek($OUTFILE, 0, 0) or croak ("$PROGRAM: error couldn't rewind temp OUTPUT file: $!\n");
    undef ($/);  # Undefine the input line terminator so we grab the whole thing
    my $cboard = <$OUTFILE>;          # Grab it ALL
    Win32::Clipboard::Set("$cboard"); # Send it to the clipboard
} # end of sub _Send_to_Clipboard


# End of functions
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

##########################################################################
# Test with 'podchecker' and see http://perldoc.perl.org/perlpod.html

=head1 NAME

DNSLookup.pl--Lookup IPAs and get hostnames


=head1 VERSION

See DNSLookup.pl -V


=head1 SYNOPSIS

  DNSLookup.pl [OPTIONS] [-i <file> | -w] [-o <file> | -W]


=head2 Examples

  DNSLookup.pl -i file -o file

  DNSLookup.pl -V


=head1 OPTIONS

  -i <file> = Input file (otherwise STDIN)
  -o <file> = Output file (otherwise STDOUT)
  -w = Take input from the Windows Clipboard instead of a file
  -W = Write output to the Windows Clipboard instead of a file

  -q = Only display the Hostname(s) in the output
  -v = Be verbose
  -V = Show version, copyright and license information

  -h = This usage


=head1 DESCRIPTION

Lookup IP Addresses and provide hostnames.

IP Addresses may be embedded in text, they will be stripped and used anyway.


=head1 DEPENDENCIES

Standard Perl modules:

    use strict
    use warnings
    use Carp
    use diagnostics
    use Socket;
    use Getopt::Std


=head1 INCOMPATIBILITIES

None known.


=head1 BUGS AND LIMITATIONS

None known.


=head1 AUTHOR / BUG REPORTS

JP Vossen (jp {at} jpsdomain {dot} org)

L<http://www.jpsdomain.org/>


=head1 LICENSE AND COPYRIGHT

Copyright 2006 JP Vossen <http://www.jpsdomain.org/>

This code is provided "as is" under the GNU GENERAL PUBLIC LICENSE

=cut
