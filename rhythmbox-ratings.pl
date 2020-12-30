#!/usr/bin/perl -w
# rhythmbox-ratings.pl--Merge "old" ratings into a new Rhythmbox XML file

#
# This worked on 2007-10-16, and 2019-12-22, but is not well tested or really "production"
# USAGE:
#    cd .local/share/rhythmbox
#    Copy rhythmdb.xml with ratings to rhythmdb.xml.STARS
#    Run: rhythmbox-ratings.pl > rhythmdb.xml.new
#    Sanity check
#    Copy rhythmdb.xml.new to rhythmdb.xml
#

# XML code based on:
# http://www.bryandonovan.com/musicmobs/musicmobs.html
#    http://www.bryandonovan.com/musicmobs/rdbxml.tar.gz
#
# See also: http://www.xmltwig.com/xmltwig/quick_ref.html

my ($type, $artist, $album, $title, $rating, );
my %rating_for;

#use strict;
use XML::Twig;

#####################################################################
# 1. Read the saved XML file containing ratings
warn "Reading ./rhythmdb.xml.STARS...\n";

my $twig = new XML::Twig;          # XML parser
$twig->parsefile("rhythmdb.xml.STARS");  # build the twig
my $root    = $twig->root;         # get the root (rhythmdb)
my @entries = $root->children;     # get the entries list

foreach my $element (@entries) {
    # $element->print;  print "\n";  # Print the entire element
    $type = $element->att('type');
    # warn "type = ~$type~\n";
    if ($type eq 'song') {    # We want: <entry type="song">
        $artist     = $element->first_child('artist')->text;
        $album      = $element->first_child('album')->text;
        $title      = $element->first_child('title')->text;
        if ($element->first_child('rating')) {
            $rating = $element->first_child('rating')->text;
            $rating_for{$artist.$album.$title} = $rating;
            # warn "rating_for{$artist.$album.$title} = $rating;\n";
        } # end of process only songs with ratings
    } # end of process only songs
} # end of foreach entry
$twig->purge;  # release memory used for this twig


# Write headers for new file
print qq(<?xml version="1.0" standalone="yes"?>\n);
print qq(<rhythmdb version="1.3">);

#####################################################################
# 2. Read the new XML file and write a new one with ratings merged in
warn "Reading ./rhythmdb.xml and writing to STDOUT...\n";

my $current_songs = new XML::Twig (pretty_print => 'indented', keep_encoding => 1);
$current_songs->parsefile("rhythmdb.xml");      # build the twig
my $current_songs_root = $current_songs->root;  # get the root (rhythmdb)
@entries  = $current_songs_root->children;      # get the entries list

foreach my $element (@entries) {
    # $element->print;  print "\n";
    $type       = $element->att('type');
    if ($type eq 'song') {
        $artist     = $element->first_child('artist')->text;
        $album      = $element->first_child('album')->text;
        $title      = $element->first_child('title')->text;
        if ( (not $element->first_child('rating')) 
              and (defined $rating_for{$artist.$album.$title}) ) {
            # We have a rating in the hash, but not in the XML, so add it
            my $rating = new XML::Twig::Elt('rating', "$rating_for{$artist.$album.$title}");
            $rating->paste('before', $element->first_child('bitrate'));
            # warn "...adding rating to $artist $album $title\n";
        }
    }
    $element->print;  # Write the element no matter what
} # end of foreach entry
$twig->purge;  # release memory used for this twig

# Write footer for new file
print qq(\n</rhythmdb>\n);
