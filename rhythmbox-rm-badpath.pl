#!/usr/bin/perl -w
# rhythmbox-rm-badpath.pl--Remove duplicate records with bad path from Rhythmbox XML file

# $Id: rhythmbox-rm-badpath.pl 1773 2011-07-16 06:47:02Z root $
# $URL: file:///home/SVN/usr_local_bin/rhythmbox-rm-badpath.pl $

# See also:
    # gconftool-2 -g /apps/rhythmbox/library_locations
    # http://blog.tappir.com/?p=13 = Python script to remove duplicate songs from Rhythmbox
    # http://ubuntuforums.org/showthread.php?t=1078839
        # wget 'http://scrawl.bplaced.net/duplicate-source.tar.gz'
        # https://launchpad.net/rb-duplicate-source

use strict;
use warnings;

my $infile  = 'rhythmdb.xml';
my $outfile = 'rhythmdb.xml.new';

my $ignored = '0'; # <entry type="ignored">
my $songs   = '0'; # <entry type="song">
my $dups    = '0'; # Duplicate song
my $other   = '0'; # Other random line in XML file
my( $aline, );

my $re_entry_type_ignore = qr!^\s*?<entry type="ignore">!;
my $re_entry_type_song   = qr!^\s*?<entry type="song">!;
my $re_end_of_entry      = qr!^\s*?</entry>!;
my $re_dup_path  = qr!^\s*?<location>file:///opt/home/jp/MyDocs/My%20Music!;


##########################################################################
# Main

open (INFILE,  '<', "$infile")  or die ("Error opening '$infile' for input: $!");
open (OUTFILE, '>', "$outfile") or die ("Error opening '$outfile' for output: $!");

print "Processing '$infile' --> '$outfile'...\n";

while ( $aline = <INFILE> ) {
    chomp($aline);
    #warn "$aline\n";

    # Junk to ignore
    if      ( $aline =~ m/$re_entry_type_ignore/ ) {
        # Throw these away
        my $trash = '';
        $ignored++;
        $trash = <INFILE> until $trash =~ m!$re_end_of_entry!;

    # A song!
    } elsif ( $aline =~ m/$re_entry_type_song/ ) {
        # Keep these unless they have the dup/bad path
        my $is_dup = '0';
        $songs++;
        my $song = "$aline\n";      # Needs newline
        until ( $aline =~ m!$re_end_of_entry! ) {
            $aline = <INFILE>;
            $is_dup = '1' if $aline =~ m!$re_dup_path/!;
            $song .= $aline;
        }
        if ( $is_dup ) {
            $dups++;
        } else {
            print OUTFILE "$song";  # No newline
        }

    # All the other cruft in there...
    } else {
        $other++;
        print OUTFILE "$aline\n";
    } # end of 'if' logic block
} # end of while input

# Footer
print "Songs:\t", $songs - $dups, "\n";
print "Dups:\t$dups\n";
print "Ignore:\t$ignored\n";
print "Other:\t$other\n";

# End of main
##########################################################################
