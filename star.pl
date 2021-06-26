#!/usr/bin/perl
# Star.pl -- Replace various strings with star "*" to allow use of 'uniq' and other tools

# $Id: star.pl 802 2005-04-01 06:09:42Z jp $
# $URL: file:///i:/home/SVN/CIS/util/star.pl $

$ver = '$Version: 1.17 $';
# parts of the time and date regex from Mastering Regular Expressions, 2nd Edition
##########################################################################
(($myname = $0) =~ s/^.*(\/|\\)//ig); # remove up to last "\" or "/"
$Greeting =  ("$myname $ver Copyright 2003-2004 CIS (JP Vossen)\n");

if ("@ARGV" =~ /^\?|^-h$|^--help$/) {
    print STDERR ("\n$Greeting\n\tUsage: $myname [OPTIONS] (-i [FILE]) (-o [FILE]}) (-q)\n\n");
    print STDERR <<'EoN';    # Various notes
  -i {infile}   = Use infile as the input file, otherwise use STDIN.
  -o {outfile}  = Use outfile as the output file, otherwise use STDOUT.
  -r = Raw output.  Default is reverse sort by frequency.
  -Q {num} = Print a dot to STDERR after processing every {num} lines,
	use -Q 0 to turn off, the default is -Q 1000.
  -q = Be quiet about it.
  -e {regex} = User defined regex as: s!{regex}!*!g
       -E {display} = User defined regex as: s!{regex}!{display}!g
  -F {patfile}  = Create a sample/template pattern file
  -f {patfile}  = Use patfile containing a list of custom expressions
  -n = Replace ALL numbers: s!\d+!*!g;
  -I = Replace ALL IPAs: s!\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}!g;

  -a = Use all of the following:
  -d = Replace date:  s!\d{1,4}([-/])(?:31|[123]0|[012]?[1-9])([-/])\d{1,4}!...
  -t = Replace time:  s!([01]?[0-9]|2[0-3]):[0-5][0-9]!*:*!g;
  -c = Replace epoCh: s!\d{9,10}\.\d{3}!epoch*!;
  -p = Replace PID:   s!(\w)\[\d+\]!$1\[*\]!g;
  -T = Replace TTY:   s!(TTY=\w+/)\d+!$1*!g;
  -P = Replace port:  s!(\d)/\d+!$1/*!g;
  -l = Replace Windows Log(on|off): s!0x0,0x[\w\d]+\) !0x0,0x*)!g;
  -D = Replace Day and month names:  s!(Mon(?:day)?|Jan(?:uary)?...!*!g;

  -A = Use all of the above AND the following:
  -N = Use names (URLs, hosts, days, months) list
  -s = Use Sanford's list (see script code)
  -S = Use SNMP list (see script code)

Replace various strings with star (*) to summarize data. For large files
it may be MUCH faster to use -f with a custom pattern file, e.g. a custom
patterns with speficic month names rather than using -D. Take a sample of
the data (head -20000) to build and test the pattern file.

Examples:
EoN
    print STDERR ("    $myname -ai input.txt\n");
    die ("    $myname -i input.txt -e \"this|that\" -E\"*\"\n");
} # end of usage

use Getopt::Std;        # Use Perl5 built-in program argument handler
getopts('i:o:rqQ:e:adtcpPDE:TlAf:F:nINsS'); # Define possible args.


if (defined $opt_Q) { # Print a progress "dot" after processing Num. of lines
    $LinesToPrintDot = $opt_Q;  # If zero, will not print anything
} else {
    $LinesToPrintDot = 1000;    # Default
} # end of if progress meter


if (defined $opt_F) {
    &CreateExpressionFileTemplate;
    exit(1);
} # end of if opt_F


if (not ($opt_e or $opt_n or $opt_a or $opt_d or $opt_t or $opt_c or $opt_p
   or $opt_P or $opt_E or $opt_T or $opt_l or $opt_A or $opt_N or $opt_s
   or $opt_S or $opt_I or $opt_f)) {
    die ("$myname: must use -a, -e or another option!\n");
} # end of if no options


if (defined $opt_A) { $opt_a = 1; }  # -A turns on -a too

if (! $opt_i) { $opt_i = "-"; } # If no input file specified, use STDIN
if (! $opt_o) { $opt_o = "-"; } # If no output file specified, use STDOUT

open (INFILE,   "$opt_i") or die ("$myname: error opening $opt_i for input: $!\n");
open (OUTFILE, ">$opt_o") or die ("$myname: error opening $opt_o for output: $!\n");

# Load in the expression file
if ($opt_f) { require $opt_f or die ("$myname: error including expression file '$opt_f': $!\n"); }


if (! $opt_q) {
    print STDERR ("\n$Greeting\n");
    print STDERR ("Processing '$opt_i' into '$opt_o'...\n");
} # end of if greeting

# Create regex objects ahead of time, and NOT in the main loop. This is a
# lot faster than recompiling them every loop.
&MakeRegexs;


if ((! $opt_q) and ($LinesToPrintDot > 0)) { print STDERR ("Each dot is $LinesToPrintDot lines processed: "); }

while ($aline = <INFILE>) {
    chomp($aline);

    study ($aline); # Learn about the line to match, to hopefully go faster

    if ($aline =~ m!^$!) {                       # Blank line
        $aline = "<<<<< Blank Line >>>>>" unless $opt_r;
    } elsif ($aline =~ m!^\s+$!) {               # White space only
        $aline = "<<<<< White space only >>>>>" unless $opt_r;
    } else {                                     # Real line to work with

        ####### Splatting
        # JP's code

        if ($opt_f) {        # Use expressions from the included file
            # I hate to call a sub from inside the main loop, but I can't see
            # any other way to do this...
            &IncludeFileSplat;
        } # end of if regxList

        if ($opt_e) {        # Use expression from the command line, if any
            if ($opt_E) {
                $aline =~ s!$regxUserDef!$opt_E!g;
            } else {
                $aline =~ s!$regxUserDef!*!g;
            } # end of in opt_E
        } # end of in opt_e

        if ($opt_I) {  # IPA (possibly with port also)
            if (($opt_a) or ($opt_P)) { $aline =~ s!$regxIPA([:/])\d+!*.*.*.*$1*!g; } # port (see below)
            $aline =~ s!$regxIPA!*.*.*.*!g;
        } # end of IPA

        if (($opt_a) or ($opt_t)) { $aline =~ s!$regxTimeL!*:*:* !g; }   # Long Time
        if (($opt_a) or ($opt_t)) { $aline =~ s!$regxTimeS!*:* !g; }     # Shrt Time
        if (($opt_a) or ($opt_d)) { $aline =~ s!$regxDate1!*$1*$2* !g; } # Date
        if (($opt_a) or ($opt_d)) { $aline =~ s!$regxDate2!MMM DD !g; }  # Date
        if (($opt_a) or ($opt_d)) { $aline =~ s!$regxDate3!DD MMM YYYY !g; }  # Date
        if (($opt_a) or ($opt_p)) { $aline =~ s!$regxPID!$1\[*\]!g; }    # PID
        if (($opt_a) or ($opt_P)) { $aline =~ s!$regxPort!$1/*!g; }      # port (see above)
        if (($opt_a) or ($opt_c)) { $aline =~ s!$regxEpoch!EPOCH!; }     # Epoch
        if (($opt_a) or ($opt_T)) { $aline =~ s!$regxTTY!$1*!g; }        # TTY
        if (($opt_a) or ($opt_l)) { $aline =~ s!$regxWLog!0x0,0x*) !g; } # Win Log(on|off)
        if (($opt_a) or ($opt_D)) {                                      # Day or Month
            $aline =~ s!$specList{AH_DAY}!*!g;
            $aline =~ s!$specList{AI_MONTH}!*!g;
        } # End of Day or Month

        # Sanford's code/lists
        if ($opt_n) { $aline =~ s!$regxNumber!*!g; }                     # Numbers

        if (($opt_A) or ($opt_N)) {    # Use names (URLs, hosts, days, months) list
            foreach $regex (keys %specList) { $aline =~ s/$specList{$regex}/*/g; }
        } # end of if specList

        if (($opt_A) or ($opt_s)) {    # Use Sanford's list
            foreach $regex (keys %regxList) { $aline =~ s/$regxList{$regex}/*/g; }
        } # end of if regxList

        if (($opt_A) or ($opt_S)) {    # Use SNMP list
            foreach $regex (keys %snmpList) { $aline =~ s/$snmpList{$regex}/$regex$1/g; }
        } # end of if regxList

    } # end of if blank or white space only


    ####### Output, part 1
    if ($opt_r) {
        print OUTFILE ("$aline\n");  # Raw output
    } else {
        $linehash{$aline}++;         # Hash it
    } # end of if raw output

    if ((! $opt_q) and ($LinesToPrintDot > 0)) {
         if ($LineCount >= $LinesToPrintDot) {
             print STDERR (".");
             $LineCount = 0;
         } else {
             $LineCount++;
         } # end of if print dot
    } # end of print progress

} # end of while input
if ((! $opt_q) and ($LinesToPrintDot > 0)) { print STDERR ("\n"); }
#print STDERR ("\n");  # Space out the screen a bit

####### Output, part 2
if (not $opt_r) {           # If not using raw output do a reverse sort by frequency
    foreach $aline (sort { $linehash{$b} <=> $linehash{$a} } keys %linehash) {
        print OUTFILE ("$linehash{$aline}\t$aline\n");
    } # end of foreach aline
} # end of if raw output

if (! $opt_q) { print STDERR ("\n\a$myname finished in ",time()-$^T," seconds.\n"); }
##########################################################################
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
sub MakeRegexs {

    # Use expressions from the included file, if used
    if ($opt_f) { &IncludeFileMakeRegexs; }

    $regxUserDef = qr!$opt_e!; # Expression from the command line, if any

    $regxTimeL = qr!(?:[01]?[0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]!;  # -t hh:mm:ss
    $regxTimeS = qr!(?:[01]?[0-9]|2[0-3]):[0-5][0-9]!;             # -t hh:mm
    $regxDate1 = qr!\d{1,4}([-/])(?:31|[123]0|[012]?[1-9])([-/])\d{1,4} !; # -d (human)
    $regxDate2 = qr!(Jan|JAN|Feb|FEB|Mar|MAR|Apr|APR|May|MAY|Jun|JUN|Jul|JUL|Aug|AUG|Sep|SEP|Oct|OCT|Nov|NOV|Dec|DEC)\s{1,2}\d{1,2} !; # -d (syslog)
    $regxDate3 = qr!\d{1,2}\s{1,2}(Jan|JAN|Feb|FEB|Mar|MAR|Apr|APR|May|MAY|Jun|JUN|Jul|JUL|Aug|AUG|Sep|SEP|Oct|OCT|Nov|NOV|Dec|DEC)\s{1,2}\d{2,4} !; # -d (syslog)
    $regxPID   = qr!(\w)\[\d+\]!;                                 # -P
    $regxPort  = qr!(\d)/\d+!;                                    # -p
    $regxEpoch = qr!\d{9,10}\.\d{3}!;                             # -e
    $regxTTY   = qr!(TTY=\w+/)\d+!;                               # -t
    $regxWLog  = qr!0x0,0x[\w\d]+\) !;                            # -l (Windows log(on|off)
    $regxIPA   = qr!\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}!;          # -I (IP Address)

    # Code from Sanford:
    # "It's a combination of a script I wrote, and a subroutine from one of
    # the filter development perl modules. Most of our filter developers use
    # it. It's only intended for residue and only works with uncompressed
    # files."

    # Splat numbers
    $regxNumber              = qr/\d+/;                             # -n

    ### -S = s/$specList{$regex}/*/g;
    # Raptor and other characteristic sensors
    $specList{RAPTOR_ID}     = qr/id=\w+/;
    $specList{RAPTOR_rid}    = qr/rid=\w+/;
    $specList{RAPTOR_RID}    = qr/rid=[A-Za-z0-9]+/;
    $specList{RAPTOR_SRCIF}  = qr/srcif=[a-z0-9]+/;
    $specList{RAPTOR_DSTIF}  = qr/dstif=[a-z0-9]+/;
    $specList{RAPTOR_MQID}   = qr/MQID=[A-Z0-9]+/;
    $specList{RAPTOR_Lspi}   = qr/Lspi=0x[0-9]+/;
    $specList{RAPTOR_Rspi}   = qr/Rspi=0x[a-z0-9]+/;
    $specList{RAPTOR_readqf} = qr/readqf: cannot open [a-zA-Z0-9]+/;
    $specList{RAPTOR_is}     = qr/is:0x[A-Z0-9]+/;
    $specList{RAPTOR_srcif}  = qr/srcif=\w+/;
    $specList{RAPTOR_dstif}  = qr/dstif=\w+/;
    $specList{RAPTOR_user}   = qr/user=\w+/;
    $specList{RAPTOR_cmd}    = qr/access to command '.*'/;

    # Norton AntiVirus
    $specList{NAV_1}         = qr/files inside [A-Z]:[\w\\.-]+/;

    # Sendmail
    $specList{SENDMAIL_1}    = qr/ [A-Z0-9]+: /;

    # RealSecure
    $specList{RS_Received}   = qr/^Received: from .*/;
    $specList{RS_addr1}      = qr/^From: RealSecure \S+$/;
    $specList{RS_addr2}      = qr/^To: \S+$/;
    $specList{RS_addr3}      = qr/at '\S+'\.$/;
    $specList{RS_URL}        = qr/^\s*URL:.*$/;
    $specList{RS_OBJECT}     = qr/^\s*OBJECT:.*$/;
    $specList{RS_QUERY}      = qr/^\s*QUERY:.*$/;
    $specList{RS_USER}       = qr/^\s*USER:.*$/;

    # Firewall-1
    $specList{FW1_dst}       = qr/dst [\w.-]+/;
    $specList{FW1_src}       = qr/src [\w.-]+/;

    # NAMED
    $specList{NAMED_server}  = qr/on '[\w.-]+'/;
    $specList{NAMED_in}      = qr/in '[\w.-]+'/;
    $specList{NAMED_last}    = qr/'[\w.-]+'$/;

    # Evntslog
    $specList{EVNTSLOG_sec}  = qr/[\w.-]+\/Security/;
    $specList{EVNTSLOG_name} = qr/User Name: [\w.-]+/;
    $specList{EVNTSLOG_domain} = qr/Domain: [\w.-]+/;
    $specList{EVNTSLOG_proc} = qr/Process:: [\w.-]+/;
    $specList{EVNTSLOG_wks}  = qr/Workstation Name:: [\\\w.-]+/;

    ### -N = s/$regxList{$regex}/*/g;
    # Somewhat less specific
    $specList{AA_EMAILADDR}  = qr/[A-Za-z0-9.-]+@[A-Za-z0-9.-]+/;
    $specList{AB_HTTP_URL}   = qr{http://\S+};
    $specList{AC_HTTPS_URL}  = qr{https://\S+};
    $specList{AD_FTP_URL}    = qr{ftp://\S+};
    $specList{AE_HOSTNAME}   = qr/[A-Za-z.-]+\.(?:com|net|mil|org|edu)/;
    $specList{AG_FILE}       = qr/[\w\/\\.-]+\/[\w\/\\.-]+/;
    $specList{AH_DAY}        = qr/(Mon(?:day)?|Tue(?:sday)?|Wed(?:nes)?|Thu(?:rsday)?|Fri(?:day)?|Sat(?:ur)?|Sun)(?:day)?/;
    $specList{AI_MONTH}      = qr/Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|June?|July?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)/;
    $specList{MACADDR}       = qr/[A-F0-9]{1,2}:[A-F0-9]{1,2}:[A-F0-9]{1,2}:[A-F0-9]{1,2}:[A-F0-9]{1,2}:[A-F0-9]{1,2}/;
  # $regxIPA, -I   $specList{AF_IPADDR}     = qr/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/;

    ### -S
    # SNMP = s/$snmpList{$regex}/$regex$1/g;
    $snmpList{BLACKICE_1}   = qr/1.3.6.1.4.1.4775.2.9.2.0(=\"\w+\")/;
    $snmpList{REALSECURE_1} = qr!iso.org.dod.internet.private.enterprises.iss.products.realSecure.v2-5.engine2-5.events2-5.event25Table.event25Entry.eventEntry!;
    $snmpList{ISS_1}        = qr!iso.org.dod.internet.private.enterprises.iss.products.common.logdata.logTable!;
    $snmpList{NETRANGER_1}  = qr!iso.netranger.nrTrapVars.!;


} # end of sub MakeRegexs
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

sub CreateExpressionFileTemplate {

    if ($opt_F eq "") { $opt_F = "sample.star" ;}

    # Open the conf file for writing only if it does not already exist! (noclobber)
    open(CONFFILE, "< $opt_F") and die ("$myname: conf file $opt_c already exists--did not create!\n");
    open(CONFFILE, "> $opt_F") or  die ("$myname: can't create $opt_c: $!");

my $cdate = scalar localtime(time);
print CONFFILE <<"EoC";
# This file is included into $myname and can be used to store multiple
# custom "splat" expressions.
# Created: $cdate

EoC
print CONFFILE <<'EoC';
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Create regex objects ahead of time, and NOT in the main loop. This is a
# lot faster than recompiling them every loop.

sub IncludeFileMakeRegexs {

    # Compile expressions, don't forget to update subscripts
    $includeList[0] = qr! {Expression 1} !;  # Comment
    # $includeList[1] = qr! {Expression 2} !; # Comment
    # $includeList[2] = qr! {Expression 3} !; # Comment

} #end of sub IncludeFileMakeRegexs


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# This sub processed before any other expressions are used...

sub IncludeFileSplat {

    # Substitute expressions, don't forget to update subscripts
    $aline =~ s!$includeList[0]!  {Replacement}  !g; # Comment
    # $aline =~ s!$includeList[1]!  {Replacement}  !g; # Comment
    # $aline =~ s!$includeList[2]!  {Replacement}  !g; # Comment

} #end of sub IncludeFileSplat

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
1;  # Return "true" for 'require' statement.
EoC
close (CONFFILE);
} #end of sub CreateExpressionFileTemplate

