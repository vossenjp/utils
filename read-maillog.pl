#!/usr/bin/perl
# read-maillog.pl--Read 'mail.log' files written by Postfix and report details

# $Id: read-maillog.pl 2207 2023-09-17 18:40:41Z root $
# $URL: file:///home/SVN/usr_local_bin/read-maillog.pl $

# TODO
    # Hande these better? last message repeated 16 times


my $VERSION   = '$Id: read-maillog.pl 2207 2023-09-17 18:40:41Z root $';
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
((my $PROGRAM = $0) =~ s/^.*(\/|\\)//); # remove up to last "\" or "/"

# Declare everything to keep -w and use strict happy
my  ( $INFILE, $OUTFILE, $debug, $verbose, $omit_greylist_report, $noqueue_only, );
our ( $opt_i, $opt_o, $opt_w, $opt_W, $opt_h, $opt_v, $opt_V, $opt_D,
      $opt_G, $opt_n, );

use strict;
use warnings; # instead of -w in perl > 5.6
use Carp; # Replace warn & die with carp & croak to show a calling stack trace
#use diagnostics; # ONLY use this during development, it slows down run-time!
use Getopt::Std;
getopts('i:o:wWhvVfD:Gn');

Usage(0)   if $opt_h;
Version(0) if $opt_V;
$verbose = $opt_v || 0;
if ($opt_D) {
    $debug   = $opt_D;  # Note lack of trailing "\n" in debug lines
    $verbose = $opt_D;  # Turn on verbose if debugging
} else {
    $debug   = 0;
}
$omit_greylist_report = $opt_G || 0;
$noqueue_only = $opt_n || 0;

# "NOQUEUE" messages, and common
my ( %count_for_status, %count_for_server, %count_for_from, %count_for_to, %ids_by_date, );
my ( $aline, $date, $status, $source, $details, $from, $to, $id, %noqueue, );
# Errors
my ( %record_with, $error, );

# "Real" message data structure
my ( %message_with, );
# %message_with = {
#    ID => {
#        date    => '',
#        from    => '',
#        to      => '',
#        source  => '',
#        status  => '',
#        details => '',
#    },
# }

my %month2num = ('Jan' => '01',
                 'Feb' => '02',
                 'Mar' => '03',
                 'Apr' => '04',
                 'May' => '05',
                 'Jun' => '06',
                 'Jul' => '07',
                 'Aug' => '08',
                 'Sep' => '09',
                 'Oct' => '10',
                 'Nov' => '11',
                 'Dec' => '12',);

#warn "\$month2num"

##########################################################################
# Main

# Open the log file
$opt_i ||= '/var/log/mail.log'; # Default
Open_IO($opt_i, $opt_o); # Open input and outfile files

# Read it
GET_INPUT:
while ($aline = <$INFILE>) {
    chomp($aline);

    # --------------------------------------------------------------------
    # Skip cruft
    next GET_INPUT if $aline =~ m/^\s*$/; # Skip blank lines
    next GET_INPUT if $aline =~ m/(^#)|(^\s*$)/; # Skip comments and white space
    # Aug 28 19:02:10 hamilton postfix/pickup[28100]: 1386412DD2A: uid=105 from=<logcheck>
    next GET_INPUT if $aline =~ m!^.*?postfix/pickup.*?from=<.*?>!;
    # Sep 25 12:52:12 drake postfix/smtpd[3936]: connect from hippolyta.jpsdomain.org[192.168.99.184]
    # Sep 25 12:52:42 drake postfix/smtpd[3945]: disconnect from localhost[127.0.0.1]
    next GET_INPUT if $aline =~ m!^.*?postfix/smtpd.*?(:?dis)?connect from!;
    # Sep 25 14:26:00 drake postfix/qmgr[18131]: 3F0D028AA10: removed
    next GET_INPUT if $aline =~ m!^.*?postfix/qmgr.*?removed$!;
    # ... postfix/anvil[6325]: statistics: ...
    next GET_INPUT if $aline =~ m!^.*?postfix/anvil.*?statistics:!;
    # Sep 25 13:04:39 drake imapd-ssl: Connection, ip=[::ffff:192.168.99.184]
    # Sep 25 13:04:39 drake imapd-ssl: LOGIN, user=karen ...
    next GET_INPUT if $aline =~ m!^.*?imapd-ssl:!;
    # Sep 25 06:26:45 bitbox nullmailer[1110]: Trigger pulled. ...
    # Sep 25 06:26:47 bitbox nullmailer[1110]: Rescanning queue. ...
    # Sep 25 06:26:48 bitbox nullmailer[1110]: Starting delivery: ...
    # Sep 25 06:26:49 bitbox nullmailer[17775]: smtp: Succeeded: ...
    # Sep 25 06:26:50 bitbox nullmailer[1110]: Sent file.
    # Sep 25 06:26:51 bitbox nullmailer[1110]: Delivery complete, ...
    next GET_INPUT if $aline =~ m!^.*?nullmailer!;
    # Sep 25 12:50:12 drake postfix/smtpd[3909]: setting up TLS connection from ...
    # Sep 25 12:50:12 drake postfix/smtpd[3909]: Anonymous TLS connection established ...
    next GET_INPUT if $aline =~ m!^.*?postfix/smtpd.*?TLS connection !;
    # Sep 25 08:34:02 hamilton3 postfix/cleanup[28624]: 3366625908: message-id=<>
    next GET_INPUT if $aline =~ m!^.*?postfix/cleanup.*?: message-id=<>$!;
    # Sep 13 19:40:30 hamilton last message repeated 16 times
    next GET_INPUT if $aline =~ m!^.*?last message repeated \d+ times$!;
    # Sep 20 13:14:22 hamilton postfix/bounce[20121]: 6A7DE12DD2E: sender delivery status notification: 6D9FC12DD30
    next GET_INPUT if $aline =~ m!^.*?postfix/bounce.*?: sender delivery status notification:!;

    # ... postgrey[26485]: action=greylist, reason=new, client_name= ...
    next GET_INPUT if $aline =~ m!^.*?postgrey.*?: action=greylist, reason=!;
    # ... postgrey[26485]: whitelisted: ...
    next GET_INPUT if $aline =~ m!^.*?postgrey.*?: whitelisted:!;
    # ... postgrey[26485]: action=pass, reason=client whitelist, client_name= ...
    # ... postgrey[26485]: action=pass, reason=triplet found, client_name= ...
    # ... postgrey[26485]: action=pass, reason=triplet found, delay= ...
    next GET_INPUT if $aline =~ m!^.*?postgrey.*?: action=pass, reason=!;
    # Sep 25 07:00:10 hamilton3 postgrey[26485]: cleaning up old logs...
    # Sep 17 03:24:26 hamilton postgrey[1900]: cleaning up old entries...
    # Sep 17 03:24:26 hamilton postgrey[1900]: cleaning main database finished. before: 430, after: 415
    # Sep 17 03:24:26 hamilton postgrey[1900]: cleaning clients database finished. before: 306, after: 295
    next GET_INPUT if $aline =~ m!^.*?postgrey.*?: cleaning !;
    # Mar  1 23:49:57 ****-mail01 postfix/smtpd[559603]: discarding EHLO keywords: CHUNKING
    next GET_INPUT if $aline =~ m!discarding EHLO keywords: CHUNKING$!;
    # Feb 28 14:47:59 ****-mail01 postfix/scache[544478]: statistics: start interval Feb 28 14:38:56
    # Feb 28 14:47:59 ****-mail01 postfix/scache[544478]: statistics: domain lookup hits=0 miss=8 success=0%
    # Feb 28 14:47:59 ****-mail01 postfix/scache[544478]: statistics: address lookup hits=0 miss=32 success=0%
    # Feb 28 14:47:59 ****-mail01 postfix/scache[544478]: statistics: max simultaneous domains=1 addresses=2 connection=2
    next GET_INPUT if $aline =~ m!^.*?postfix/scache.*?statistics:!;


    # --------------------------------------------------------------------
    # NOQUEUE messages do not have an ID, since they are never accepted.
    # But they are also all on one line (more-or-less) so we can just do
    # everything at once.
    if      ( $aline =~ m/^(.{15}).*?: NOQUEUE: (\w+): RCPT from (.*?): \d+ [\d.]+ (.*?); from=(<.*?>) to=<(.*?)>/ ) {
        # zgrep -h ': NOQUEUE:' /home/SERVERS/hamilton/var/log/mail.log* > /tmp/NOQUEUE
        # Sep 18 09:15:58 hamilton postfix/smtpd[24033]: NOQUEUE: reject: RCPT from e3uspmta166.emarsys.net[91.194.248.166]: 450 4.2.0 <karen@jpsdomain.org>: Recipient address rejected: Greylisted, see http://postgrey.schweikert.ch/help/jpsdomain.org.html; from=<e3us-1623334985760-1d71a7II5eaccb@us.emarsys.net> to=<karen@jpsdomain.org> proto=ESMTP helo=<e3uspmta166.emarsys.net>
        # Sep 22 06:25:43 hamilton postfix/smtpd[12782]: NOQUEUE: reject: RCPT from 195-64-178-81.botosani.city-net.ro[195.64.178.81]: 554 5.7.1 Service unavailable; Client host [195.64.178.81] blocked using zen.spamhaus.org; http://www.spamhaus.org/query/bl?ip=195.64.178.81; from=<admin@westernunion.com> to=<admin@jpsdomain.org> proto=ESMTP helo=<195-64-178-81.botosani.city-net.ro>
        # Sep 19 06:05:52 hamilton postfix/smtpd[20048]: NOQUEUE: reject: RCPT from n246z151l97.broadband.ctm.net[60.246.151.97]: 554 5.7.1 Service unavailable; Client host [60.246.151.97] blocked using dul.dnsbl.sorbs.net; Dynamic IP Addresses See: http://www.sorbs.net/lookup.shtml?60.246.151.97; from=<childbirthqec@porterorlin.com> to=<fwm@jpsdomain.org> proto=ESMTP helo=<n246z151l97.broadband.ctm.net>
        # Sep 18 08:05:27 hamilton postfix/smtpd[2937]: NOQUEUE: reject: RCPT from 58.6.222.87.dynamic.jazztel.es[87.222.6.58]: 504 5.5.2 <user-eddfaf3480>: Helo command rejected: need fully-qualified hostname; from=<fdfywsc@163.com> to=<jp@jpsdomain.org> proto=SMTP helo=<user-eddfaf3480>
        # Sep 25 08:34:02 hamilton3 postfix/smtp[28625]: 46F202606A: to=<jp-work@jpsdomain.org>, relay=drake.jpsdomain.org[173.49.93.110]:587, delay=0.15, delays=0/0/0.11/0.04, dsn=5.1.1, status=bounced (host drake.jpsdomain.org[173.49.93.110] said: 550 5.1.1 <jp-work@jpsdomain.org>: Recipient address rejected: User unknown in local recipient table (in reply to RCPT TO command))
        # Sep 18 19:34:41 hamilton postfix/smtpd[5386]: NOQUEUE: reject: RCPT from 131stb68.codetel.net.do[66.98.18.131]: 450 4.1.8 <fyxwrum@zneci.com>: Sender address rejected: Domain not found; from=<fyxwrum@zneci.com> to=<karen@jpsdomain.org> proto=SMTP helo=<131stb68.codetel.net.do>
        $date    = "$1";
        $status  = "$2";
        $source  = "$3";  # Remote mail server (or user client)
        $details = "$4";
        $from    = "$5";
        $to      = "$6";

        if ( $details =~ m/Recipient address rejected: Greylisted/ ) {
            $status = 'Greylisted'  if $details =~ m/Recipient address rejected: Greylisted/;
            next if $omit_greylist_report;
        }
        $status .= '; spamhaus' if $details =~ m/blocked using zen.spamhaus.org/;
        $status .= '; sorbs'    if $details =~ m/blocked using dul.dnsbl.sorbs.net/;
        $status .= '; need FQH' if $details =~ m/need fully-qualified hostname/;
        $status .= '; User unknown' if $details =~ m/User unknown in local recipient table/;
        $status .= '; domain not found' if $details =~ m/Domain not found/;

        # These are one line, so we have everything in one shot.  We may see if
        # again, but if we do it's because the remote server tried again too
        # soon (e.g. comcast), and we do want to know that.
        $count_for_status{$status} ++;
        $count_for_server{$source} ++;
        $count_for_from{$from} ++;
        $count_for_to{$to} ++;

        if ( $verbose ) {
            $noqueue{"$date\tNOQUEUE\t$from\t$to\t$source\t$status\t$details"}++;
        } else {
            $noqueue{"$date\tNOQUEUE\t$from\t$to\t$source\t$status"}++;
        }


    # --------------------------------------------------------------------
    # "Real" messages have an ID, but are split into several lines! :-(
    # So we need to build a data structure to collect the parts
    } elsif ( $aline =~ m/^(.{15}).*?: (\w+): message-id=<.*?@(.*?)>/ ) {
        # zgrep -h 'message-id=' /home/SERVERS/hamilton/var/log/mail.log* > /tmp/sent
        # ...: 4816F28A0A0: message-id=<20110918104708.4816F28A0A0@drake.jpsdomain.org>
        # Sep 18 06:47:08 drake postfix/cleanup[24630]: 4816F28A0A0: message-id=<20110918104708.4816F28A0A0@drake.jpsdomain.org>
        $date   = "$1";
        $id     = "$2";
        $source = "$3";  # Remote mail server (or user client)

        # Do counters later.

        $ids_by_date{$id}           = Sortable_Syslog("$date");
        $message_with{$id}{date}    = "$date";
        $message_with{$id}{source}  = "$source";
        warn "MSG:\t$id\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^(.{15}).*?: (\w+): client=(.*)/ ) {
        # zgrep -h 'client=' /home/SERVERS/hamilton/var/log/mail.log* > /tmp/sent
        # ...: C315728AA10: client=mail.jpsdomain.org[66.228.58.184]
        # Sep 25 14:26:19 drake postfix/smtpd[6323]: C315728AA10: client=mail.jpsdomain.org[66.228.58.184]
        $date   = "$1";
        $id     = "$2";
        $source = "$3";  # Remote mail server (or user client)

        # Do counters later.

        $ids_by_date{$id}           = Sortable_Syslog("$date");
        $message_with{$id}{date}    = "$date";
        $message_with{$id}{source}  = "$source";
        warn "MSG:\t$id\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^(.{15}).*?: (\w+): to=<(.*?)>, .*? status=(\w+) \((\w+)/ ) {
        # zgrep -h 'status=' /home/SERVERS/hamilton/var/log/mail.log* > /tmp/sent
        # ...: 4816F28A0A0: to=<root@drake.jpsdomain.org>, ... status=sent (forwarded as 5994628A09E)
        # Sep 18 06:47:08 drake postfix/local[24632]: 4816F28A0A0: to=<root@drake.jpsdomain.org>, orig_to=<root>, relay=local, delay=5.8, delays=5.8/0.01/0/0.02, dsn=2.0.0, status=sent (forwarded as 5994628A09E)
        $date    = "$1";
        $id      = "$2";
        $to      = "$3";
        $status  = "$4";
        $details = "$5";

        # Do counters later.

        $ids_by_date{$id}           = Sortable_Syslog("$date");
        $message_with{$id}{date}    = "$date";
        $message_with{$id}{to}      = "$to";
        $message_with{$id}{status}  = "$status";
        $message_with{$id}{details} = "$details";
        warn "TO:\t$id\t$to\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^(.{15}).*?: (\w+): from=(<.*?>),/ ) {
        # zgrep -h '' /home/SERVERS/hamilton/var/log/mail.log* > /tmp/sent
        # ...: 4816F28A0A0: from=<root@drake.jpsdomain.org>, ...
        # Sep 18 06:47:08 drake postfix/qmgr[2503]: 4816F28A0A0: from=<root@drake.jpsdomain.org>, size=35242, nrcpt=1 (queue active)
        $date = "$1";
        $id   = "$2";
        $from = "$3";

        # Do counters later.

        $ids_by_date{$id}        = Sortable_Syslog("$date");
        $message_with{$id}{date} = "$date";
        $message_with{$id}{from} = "$from";
        warn "FROM:\t$id\t$from\n" if ( $debug >= 2 );

    # --------------------------------------------------------------------
    # Various errors
    } elsif ( $aline =~ m/^.*?: lost connection after RCPT from unknown\[(.*?)\]$/ ) {
        # zgrep -h 'lost connection after RCPT from unknown' /home/SERVERS/hamilton/var/log/mail.log* > /tmp/lost
        # ... : lost connection after RCPT from unknown[46.181.3.168]
        # Sep 25 06:29:28 hamilton3 postfix/smtpd[3252]: lost connection after RCPT from unknown[46.181.3.168]
        $error = "Lost connection after RCPT from unknown\t$1";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^.*?: connect to (.*?): Connection timed out$/ ) {
        # ...: connect to drake.jpsdomain.org[173.49.93.110]:25: Connection timed out
        # Sep 25 14:36:51 hamilton3 postfix/smtp[25679]: connect to drake.jpsdomain.org[173.49.93.110]:25: Connection timed out
        $error = "Connection timed out\t$1";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^.*?: warning: (.*?) hostname (.*?) verification failed: Name or service not known$/ ) {
        # ...: warning: 74.63.193.196: hostname ...  verification failed: Name or service not known
        # Sep 25 14:26:19 hamilton3 postfix/smtpd[17919]: warning: 74.63.193.196: hostname 196-193-63-74.reverse.lstn.net verification failed: Name or service not known
        $error = "Verification failed: Name or service not known\t$1\t$2";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^.*?: warning: (.*?) address not listed for hostname (.*?)$/ ) {
        # ...: warning: 222.255.28.33: address not listed for hostname static.vdc.vn
        # Sep 25 07:07:01 hamilton3 postfix/smtpd[12016]: warning: 222.255.28.33: address not listed for hostname static.vdc.vn
        $error = "Address not listed for hostname\t$1\t$2";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^.*?: lost connection after STARTTLS from (.*?)$/ ) {
        # ...: lost connection after STARTTLS from vip1scan.telenor.net[148.123.15.75]
        # Sep 25 12:13:34 hamilton3 postfix/smtpd[8073]: lost connection after STARTTLS from vip1scan.telenor.net[148.123.15.75]
        $error = "Lost connection after STARTTLS from\t$1";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^.*?: SSL_accept error from (.*?)$/ ) {
        # ...: SSL_accept error from vip1scan.telenor.net[148.123.15.75]: 0
        # Sep 25 12:13:34 hamilton3 postfix/smtpd[8073]: SSL_accept error from vip1scan.telenor.net[148.123.15.75]: 0
        $error = "SSL_accept error from\t$1";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^.*?: warning: TLS library problem:/ ) {
        # ...: warning: TLS library problem: ...
        # Sep 25 12:13:34 hamilton3 postfix/smtpd[8073]: warning: TLS library problem: 8073:error:14094412:SSL routines:SSL3_READ_BYTES:sslv3 alert bad certificate:s3_pkt.c:1102:SSL alert number 42:
        $error = "TLS library problem";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^.*?: sender non-delivery notification: (.*)$/ ) {
        # ...: 3366625908: sender non-delivery notification: 46F202606A
        # Sep 25 08:34:02 hamilton3 postfix/bounce[28626]: 3366625908: sender non-delivery notification: 46F202606A
        $error = "Sender non-delivery notification\t$1";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^.*?: lost connection after RCPT from (.*)$/ ) {
        # ...: lost connection after RCPT from 77.Red-95-124-204.staticIP.rima-tde.net[95.124.204.77]
        # Sep 25 13:48:20 hamilton3 postfix/smtpd[16925]: lost connection after RCPT from 77.Red-95-124-204.staticIP.rima-tde.net[95.124.204.77]
        $error = "Lost connection after RCPT from\t$1";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^.*?: lost connection after (.*?) from (.*)$/ ) {
        # ...: lost connection after DATA (0 bytes) from unknown[119.234.197.193]
        # Sep 16 12:47:38 hamilton postfix/smtpd[18527]: lost connection after DATA (0 bytes) from unknown[119.234.197.193]
        # Sep 16 13:57:22 hamilton postfix/smtpd[19708]: lost connection after CONNECT from unknown[unknown]
        $error = "Lost connection after $1\t$2";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^.*?: enabling PIX workarounds: (.*?) for (.*)$/ ) {
        # ...: enabling PIX workarounds: disable_esmtp delay_dotcrlf for cfcumail01.citadelbanking.com[207.106.145.212]:25
        # Sep 14 15:32:45 hamilton postfix/smtp[4108]: 736DE12DCDD: enabling PIX workarounds: disable_esmtp delay_dotcrlf for cfcumail01.citadelbanking.com[207.106.145.212]:25
        $error = "Enabling PIX workarounds: $1\t$2";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^.*?: timeout after (.*?) from (.*)$/ ) {
        # ...: timeout after DATA (1012 bytes) from mta811.email.childrensplace.com[63.146.96.249]
        # Sep 16 04:11:22 hamilton postfix/smtpd[5556]: timeout after DATA (1012 bytes) from mta811.email.childrensplace.com[63.146.96.249]
        # ...: timeout after END-OF-MESSAGE from client-1-178.delivery.net[209.11.164.178]
        # Sep 12 07:23:36 hamilton postfix/smtpd[28275]: timeout after END-OF-MESSAGE from client-1-178.delivery.net[209.11.164.178]
        $error = "Timeout after $1\t$2";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^.*?: warning: Illegal address syntax from (.*?) in (\w+) command: (.*)$/ ) {
        # ...: warning: Illegal address syntax from unknown[110.139.180.34] in MAIL command: <united parcel service.notification center@ups.com>
        # Sep 12 06:43:59 hamilton postfix/smtpd[27206]: warning: Illegal address syntax from unknown[110.139.180.34] in MAIL command: <united parcel service.notification center@ups.com>
        $error = "Illegal address syntax in $2\t$1\t$3";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^.*?: host (.*?) refused to talk to me: (.*?)\((.*?)\)$/ ) {
        # ...: CB6CF12DCDB: host b.mx.mail.yahoo.com[74.6.136.65] refused to talk to me: 420 Resources unavailable temporarily. Please try later (mta1073.mail.sk1.yahoo.com)
        # Aug 29 17:46:37 hamilton postfix/smtp[15200]: CB6CF12DCDB: host b.mx.mail.yahoo.com[74.6.136.65] refused to talk to me: 420 Resources unavailable temporarily. Please try later (mta1073.mail.sk1.yahoo.com)
        $error = "Refushed to talk: $2\t$1\t$3";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^.*?: lost connection with (.*?) while receiving the initial server greeting$/ ) {
        # ...: lost connection with ... while receiving the initial server greeting
        # Sep 21 04:34:34 hamilton postfix/smtp[29117]: ED11B12DCDE: lost connection with cluster5.us.messagelabs.com[216.82.250.51] while receiving the initial server greeting
        $error = "Lost connection while receiving greeting\t$1";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^.*?: connect to (.*?): Connection refused$/ ) {
        # ...: connect to mailserver.com[208.87.32.69]:25: Connection refused
        # Sep 25 16:59:33 hamilton3 postfix/smtp[3186]: connect to mailserver.com[208.87.32.69]:25: Connection refused
        $error = "Connection refused\t$1";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^.*?: improper command pipelining after QUIT from (.*?)$/ ) {
        # ...: improper command pipelining after QUIT from static-98-114-135-53.phlapa.fios.verizon.net[98.114.135.53]
        # Sep 28 14:59:32 hamilton3 postfix/smtpd[21673]: improper command pipelining after QUIT from static-98-114-135-53.phlapa.fios.verizon.net[98.114.135.53]
        $error = "Improper command pipelining after QUIT\t$1";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^.*?: using backwards-compatible default setting append_dot_mydomain=yes to rewrite (.*?)$/ ) {
        # ...: using backwards-compatible default setting append_dot_mydomain=yes to rewrite
        # Mar  1 12:00:02 lc-prod-mail01 postfix/trivial-rewrite[553759]: using backwards-compatible default setting append_dot_mydomain=yes to rewrite "****-mail01" to "****-mail01.*********.com"
        $error = "Append_dot_mydomain\t$1";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );


    # --------------------------------------------------------------------
    # Various attacks
    } elsif ( $aline =~ m/^.*?: warning: SASL authentication failure: (.*)$/ ) {
        # ...: warning: SASL authentication failure: need authentication name
        # Sep 16 01:42:21 hamilton postfix/smtpd[26353]: warning: SASL authentication failure: need authentication name
        # ...: warning: SASL authentication failure: no secret in database
        # Sep 16 02:08:22 hamilton postfix/smtpd[26353]: warning: SASL authentication failure: no secret in database
        #
        $error = "ATTACK: SASL authentication failure:\t$1";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^.*?: warning: (.*?): SASL (\w+) authentication failed?: (.*)$/ ) {
        # ...: warning: unknown[12.237.237.115]: SASL LOGIN authentication failed: authentication failure
        # Sep 21 14:21:55 hamilton postfix/smtpd[29530]: warning: unknown[12.237.237.115]: SASL LOGIN authentication failed: authentication failure~
        # ...: warning: unknown[12.237.237.115]: SASL PLAIN authentication failed: authentication failure
        # Sep 21 14:22:10 hamilton postfix/smtpd[29521]: warning: unknown[12.237.237.115]: SASL PLAIN authentication failed: authentication failure
        $error = "ATTACK: SASL $1 authentication failed: $2\t$3";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^.*?: warning: (.*?): SASL CRAM-MD5 authentication failed: (.*)$/ ) {
        # ...: warning: host113-209-static.119-2-b.business.telecomitalia.it[2.119.209.113]: SASL CRAM-MD5 authentication failed: bad protocol / cancel
        # Sep 16 01:42:21 hamilton postfix/smtpd[26353]: warning: host113-209-static.119-2-b.business.telecomitalia.it[2.119.209.113]: SASL CRAM-MD5 authentication failed: bad protocol / cancel
        # ...: warning: host113-209-static.119-2-b.business.telecomitalia.it[2.119.209.113]: SASL CRAM-MD5 authentication failed: authentication failure
        # Sep 16 02:05:29 hamilton postfix/smtpd[26353]: warning: host113-209-static.119-2-b.business.telecomitalia.it[2.119.209.113]: SASL CRAM-MD5 authentication failed: authentication failure
        $error = "ATTACK: SASL CRAM-MD5 authentication failed: $1\t$2";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );
    } elsif ( $aline =~ m/^.*?: too many errors after AUTH from (.*)$/ ) {
        # ...: too many errors after AUTH from host113-209-static.119-2-b.business.telecomitalia.it[2.119.209.113]
        # Sep 16 02:20:16 hamilton postfix/smtpd[26323]: too many errors after AUTH from host113-209-static.119-2-b.business.telecomitalia.it[2.119.209.113]
        $error = "ATTACK: Too many errors after AUTH\t$1";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );

    # --------------------------------------------------------------------
    # Warning catch-all: MUST BE NEXT-TO LAST
    } elsif ( $aline =~ m/^.*?: warning: (.*)$/ ) {
        # ...: warning: valid_hostname: empty hostname~
        # ~Sep 13 20:29:48 hamilton postfix/smtpd[8984]: warning: valid_hostname: empty hostname~
        # ...: warning: malformed domain name in resource data of MX record for uemq.com: ~
        # ~Sep 13 20:29:48 hamilton postfix/smtpd[8984]: warning: malformed domain name in resource data of MX record for uemq.com: ~
        $error = "Catch-all: warning:\t$1";
        $record_with{$error}++;
        warn "ERROR:\t$error\n" if ( $debug >= 2 );

    # --------------------------------------------------------------------
    # Fail-safe
    # --------------------------------------------------------------------
    } else  {
        warn "UNPARSED: ~$aline~\n";
    } # end of parsing
} # end of while ($aline = <$INFILE>)


# ------------------------------------------------------------------------
# Output
# ------------------------------------------------------------------------
print $OUTFILE "NOQUEUE messages\n";
if ( $verbose ) {
    print $OUTFILE "Date\tID\tFrom\tTo\tSource\tStatus\tDetails\tCount\n";
} else {
    print $OUTFILE "Date\tID\tFrom\tTo\tSource\tStatus\tCount\n";
}
foreach my $message ( sort keys %noqueue ) {
    print $OUTFILE "$message\t$noqueue{$message}\n";
}


# ------------------------------------------------------------------------
print $OUTFILE "\nMessages\n";
unless ( $noqueue_only ) {
    print $OUTFILE "Date\tID\tFrom\tTo\tSource\tStatus\tDetails\n";
    foreach my $id ( sort { $ids_by_date{$a} cmp $ids_by_date{$b} } keys %ids_by_date ) {

        # Make sure all elements are initialized, both to prevent "Use of
        # uninitialized value in ..." errors and to keep the counters clean
        $message_with{$id}{from}    = '' if not defined $message_with{$id}{from};
        $message_with{$id}{to}      = '' if not defined $message_with{$id}{to};
        $message_with{$id}{source}  = '' if not defined $message_with{$id}{source};
        $message_with{$id}{status}  = '' if not defined $message_with{$id}{status};
        $message_with{$id}{details} = '' if not defined $message_with{$id}{details};

        # Actually print a record (finally!)
        print $OUTFILE
              "$message_with{$id}{date}\t"
            . "$id\t"
            . "$message_with{$id}{from}\t"
            . "$message_with{$id}{to}\t"
            . "$message_with{$id}{source}\t"
            . "$message_with{$id}{status}\t"
            . "$message_with{$id}{details}\n";

        # Do the counters HERE, because we may see the same one several times above
        # due to the multi-line nature of the logging.
        $count_for_from{$message_with{$id}{from}} ++;
        $count_for_to{$message_with{$id}{to}} ++;
        $count_for_server{$message_with{$id}{source}} ++;
        $count_for_status{$message_with{$id}{status}} ++;
    } # end of foreach $id
} # end of unless ( $noqueue_only )


# ------------------------------------------------------------------------
# Display Error messages (regardless of $noqueue_only)
print $OUTFILE "\nErrors\n";
print $OUTFILE "Count\tERROR\tHost\n";
foreach my $error ( sort { $record_with{$b} <=> $record_with{$a} } keys %record_with ) {
    print $OUTFILE "$record_with{$error}\t$error\n";
}


# ------------------------------------------------------------------------
# Display counters
unless ( $noqueue_only ) {
    print $OUTFILE "\nCounters";
    Display (\%count_for_status, 'Status code');
    Display (\%count_for_server, 'Mail Servers');
    Display (\%count_for_from,   'From');
    Display (\%count_for_to,     'To');
} # end of unless ( $noqueue_only )

# End of main
##########################################################################


# Subroutines
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Emit usage information
# Returns:  nothing, just exits
sub Usage {
    # Called like: Usage (<exit code>)
    my $exit_code = $_[0] || 1; # Default of 1 if exit code not specified
    # Call system in a(n ugly) list context so we don't spawn a sub-shell
    # and so we avoid all (possibly insecure) aspects of *shell* interpolation
    system ("perldoc", "$0");
    ## --or--
    #system ("pod2usage", "-verbose", "1", "$0");
    #print ("\nFor complete documentation please see 'perldoc $0'\n");
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
# Displays the counter hashs
# Returns:  nothing
sub Display {
    @_ == 2 or croak ('Usage:  Display(\%hash, "Title");');
    my ( $hash_ref, $title, ) = @_;
    my ( $item, );

    print $OUTFILE "\nCount\t$title\n";
    foreach $item (sort { ${$hash_ref}{$b} <=> ${$hash_ref}{$a} } keys %{$hash_ref}) {
        print $OUTFILE "${$hash_ref}{$item}\t$item\n";
    } # end of foreach ipa

# FIXME    if ($debug >= 1) { carp ("Debug message here"); }

    return scalar 1;
} # end of sub Display


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Sortable_Syslog the crappy old syslog data into something sortable
# Returns:  sortable data
sub Sortable_Syslog {
    @_ == 1 or croak ('Usage:  Sortable_Syslog("$date");');
    my ( $syslog_date, ) = @_;
    my ( $sortable_date, );

    # FROM: Oct  3 21:37:43
    # TO:   10-03-21:37:43
    $sortable_date =  $syslog_date;
    $sortable_date =~ s/^(\w+)/$month2num{$1}/e;  # Month name to 2 digit
    $sortable_date =~ s/^(\d{2})  (\d) /$1-0$2-/; # Add leading zero to 1 digit
    $sortable_date =~ s/ /-/g;                    # Any spaces to -

    warn "syslog_date = ~$syslog_date~\tsortable_date = ~$sortable_date~\n" if ( $debug >= 2 );

    return "$sortable_date";
} # end of sub Sortable_Syslog


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
        $INFILE = tmpfile() or croak ("Error creating temp file for -w: $!");
        print $INFILE ("$cboard");
        seek($INFILE, 0, 0) or croak ("Error couldn't rewind temp INPUT file: $!");
    } elsif ($opt_w and ($^O ne "MSWin32")) {
        croak ("$PROGRAM: can't use -w on Linux or Unix!  What're you thinking?!?\n");
    } else {
        # Regular old input (prefer 3 argument open if possible)
        if ("$infile" eq '-') {
            open ($INFILE, '<-')           or croak ("Error opening STDIN for input: $!");
        } else {
            open ($INFILE, '<', "$infile") or croak ("Error opening '$infile' for input: $!");
        } # end of if STDIN
    } # end of get input from clipboard

    # Output
    if ($opt_W and ($^O eq "MSWin32")) { # We're sending the output directly into the Clipboard
        eval "use Win32::Clipboard;";    # Import clipboard but don't die if we're not on Windows
        # Use a secure temp file that's automatically deleted when we're finished.
        use File::Temp;
        $OUTFILE = tmpfile() or croak ("Error creating temp file for -W: $!");
    } elsif ($opt_W and ($^O ne "MSWin32")) {
        croak ("$PROGRAM: can't use -W on Linux or Unix!  What're you thinking?!?\n");
    } else {
        # Regular old output (prefer 3 argument open if possible)
        # Note use of indirect file handle (e.g. '$' on $OUTFILE), needed for temp file
        if ("$outfile" eq '-') {
            open ($OUTFILE, '>-')            or croak ("Error opening STDOUT for output: $!");
        } else {
            open ($OUTFILE, '>', "$outfile") or croak ("Error opening '$outfile' for output: $!");
        } # end of if STDOUT
    } # end of if using clipboard
} # end of sub Open_IO


##########################################################################
# Test with 'podchecker' and see http://perldoc.perl.org/perlpod.html

=head1 NAME

read-maillog.pl--Read 'mail.log' files written by Postfix and report details

=head1 VERSION

$Id: read-maillog.pl 2207 2023-09-17 18:40:41Z root $

See read-maillog.pl -V


=head1 SYNOPSIS

  read-maillog.pl [OPTIONS] [-i <file> | -w] [-o <file> | -W]


=head2 Examples

  read-maillog.pl -i /var/log/mail.log -o /tmp/report

  read-maillog.pl -V


=head1 OPTIONS

  -i <file> = Input file (otherwise /var/log/mail.log, use '-' for STDIN).
  -o <file> = Output file (otherwise STDOUT).
  -w = Take input from the Windows Clipboard instead of a file.
  -W = Write output to the Windows Clipboard instead of a file.
  -h = This usage.
  -v = Be verbose.
  -V = Show version, copyright and license information.

  -n = Report on NOQUEUE (and error) records only, omit everything else
  -G = Omit Postgrey records
  -D <level> = Print debug messages to STDERR (level = 1-3).


=head1 DESCRIPTION

Postfix /var/log/mail.log (or mail.err) files are annoying to t-shoot because
they are multi-line and multi-threaded, so the full details of a single message
may be a bit scattered in the log.  This script pulls the pieces together to
make it easier to review and/or troubleshoot.

The output is tab delimited for easy reading or filtering in a spreadsheet.

=cut
