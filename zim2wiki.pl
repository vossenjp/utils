#!/usr/bin/perl
# zim2wiki.pl--Trivially convert Zim markup to Redmine or Mediawiki
# Original Author/date: JP, 2013-10-17
my $VERSION = '$Id: zim2wiki.pl 2078 2018-12-15 22:01:39Z root $';
#_________________________________________________________________________

our ( $opt_h, $opt_m, );

use strict;
use warnings;
use Getopt::Std;
getopts('hm');

if ( $opt_h ) {
    print "Convert Zim markup to Redmine or Mediawiki\n";
    print "<STDIN> | $0 (-h) (-r|-m) | <STDOUT>\n";
    print "-h  = this help\n";
    print "-m  = Convert to Mediawiki instead of the default Redmine (textile)\n";
    exit 0;
}

my $URL_REDMINE = qr'REDACTED';
my $URL_MOES    = qr'REDACTED';
#my $URL_SVN = 'REDACTED'; # not used (yet)?

# FIXME: need an option for Redmine vs Mediawiki markup
#my $bullet = '*';

while (<>) {

    if ( $opt_m ) {
        ### Mediawiki
        # Convert headings (must do BEFORE converting to numbers!)
        s/^=+/== ==/;                      # Next line!  :-(
        s/^-+/=== ===/;                    # Next line!  :-(
        s/^### (.*)$/==== $1 ====/;        # Inline
        s/^#### (.*)$/===== $1 =====/;     # Inline
        s/^##### (.*)$/====== $1 ======/;  # Inline
        # TODO
        # Zim *bold*   = '''bold'''
        # Zim *italic* = ''italic''

        # URL
        s!$URL_MOES/(.*)$![[$1]]!g;

        # Code
        s!\b`(\S+)!<code>$1!g;
        s!(\S+)`\b!$1</code>!g;

    } else {
        ### Redmine (textile)
        # Convert headings (must do BEFORE converting to numbers!)
        s/^=+/h1. /;      # Next line!  :-(
        s/^-+/h2. /;      # Next line!  :-(
        s/^### /h3. /;    # Inline
        s/^#### /h4. /;   # Inline
        s/^##### /h5. /;  # Inline
        # TODO
        # Zim *bold*       = *bold*
        # Zim *italic*     = _italic_
        # Zim _hightlight_ = +underline+

        # URLs
        s!$URL_REDMINE/issues/(\d+)#note-(\d+)!#$1-$2!g;
        s!$URL_REDMINE/issues/(\d+)!#$1!g;
        s!$URL_REDMINE/news/(\d+)!news#$1!g;
        s!$URL_REDMINE/[\w/]+/wiki/(.*)$![[$1]]!g;

        # Code
        s/\B`(\S+)/\@$1/g;
        s/(\S+)`\B/$1\@/g;
    }

    ### SAME for Mediawiki and Redmine
    # Convert various "[]" to "#"
    s/^(\s*)\[ \]\s+/$1# [ ] /;
    s/^(\s*)\[x\]\s+/$1# [x] /;
    s/^(\s*)\[>\]\s+/$1# [>] /;
    s/^(\s*)\[\*?\]\s+/$1# /;
    # Convert numbers to "#"
    s/^(\s*)\d+\. /$1# /;

    # Convert leading tabs to the same number of bullet
    #s/^(\t+)([#*])/"$2" x (length($1)-1)/e;
    #s/^(\t+)([#*])/"$2" x (length($1)+1)/e;
    s/^(\t+)([#*])/"$2" x (length($1))/e;

    print;
}
