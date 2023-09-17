#!/usr/bin/perl
# zim2wiki.pl--Trivially convert Zim markup to Redmine or Mediawiki
# Original Author/date: JP, 2013-10-17
my $VERSION = '$Id: zim2wiki.pl 2183 2021-10-05 00:34:56Z root $';
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

while (<>) {
    if ( $opt_m ) {
        ### Mediawiki
        # Convert headings (must do BEFORE converting to numbers!)
        # OLD, Zim < 0.74.0
        #s/^=+/== ==/;
        #s/^-+/=== ===/;
        #s/^### (.*)$/==== $1 ====/;
        #s/^#### (.*)$/===== $1 =====/;
        #s/^##### (.*)$/====== $1 ======/;
        s/^=====(.*?)=====$/==$1==/;    # h2
        s/^====(.*?)====$/===$1===/;    # h3
        s/^===(.*?)===$/====$1====/;    # h4
        s/^===(.*?)==$/=====$1=====/;   # h5
        s/^==(.*?)==$/======$1======/;  # h6
        # TODO
        # Zim *bold*   = '''bold'''
        # Zim *italic* = ''italic''

        # Code
        s!\b`(\S+)!<code>$1!g;
        s!(\S+)`\b!$1</code>!g;

    } else {
        ### Redmine (textile)
        # Convert headings (must do BEFORE converting to numbers!)
        # OLD, Zim < 0.74.0
        #s/^=+/h1. /;      # Next line!  :-(
        #s/^-+/h2. /;      # Next line!  :-(
        #s/^### /h3. /;    # Inline
        #s/^#### /h4. /;   # Inline
        #s/^##### /h5. /;  # Inline
        s/^=====/h2./;     # Inline h2, etc...
        s/^====/h3./;
        s/^===/h4./;
        s/^==/h5./;
        s/ =+$//;          # Clean up right side cruft: ===

        # Formatting
        s/\*\*(.+?)\*\*/*$1*/g;           # **bold**      to *bold*
        s~(?<!:)//(.+?)(?<!:)//~_$1_~g;   # //italic//    to _italic_
        s/__(.+?)__/+$1+/g;               # __highlight__ to +underline+
        s/''(.+?)''/\@$1\@/g;             # ''code''      to @code@
        s/~~(.+?)~~/-$1-/g;               # ~~strike~~    to -strike-
        # Note negative look-behind for ":" (like https://) in italics!

        # Other Code (good/needed?)
        s/\B`(\S+)/\@$1/g;
        s/(\S+)`\B/$1\@/g;
    }

    ### SAME for Mediawiki and Redmine
    # Convert various Zim checkboxes "[]" to "#"
    s/^(\s*)\[ \]\s+/$1# [ ] /;
    s/^(\s*)\[x\]\s+/$1# [x] /;
    s/^(\s*)\[>\]\s+/$1# [>] /;
    s/^(\s*)\[<\]\s+/$1# [<] /;
    s/^(\s*)\[\*?\]\s+/$1# /;
    # Convert numbers to "#"
    s/^(\s*)\d+\. /$1# /;

    # Convert leading tabs to the same number of bullet
    #s/^(\t+)([#*])/"$2" x (length($1)-1)/e;
    #s/^(\t+)([#*])/"$2" x (length($1)+1)/e;
    s/^(\t+)([#*])/"$2" x (length($1))/e;

    print;
}  # end of while file input
