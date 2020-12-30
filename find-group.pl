#!/usr/bin/perl
# find-group.pl--Find a group containing the most users from a list

# $URL: file:///home/SVN/usr_local_bin/find-group.pl $
# $Id: find-group.pl 1824 2012-08-27 06:14:19Z root $

use strict;
use warnings;

my ( %group, %users, %members_of, %missing_from, $aline, );
my $etc_group = '/etc/group';
my $user_list = 'users.txt';
open (ETC_GROUP, '<', "$etc_group") or die ("Error opening '$etc_group' for input: $!");
open (USERS,     '<', "$user_list") or die ("Error opening '$user_list' for input: $!");


USER_INPUT:
while ($aline = <USERS>) {
    chomp($aline);
    next USER_INPUT if $aline =~ m/(^#)|(^\s*$)/; # Skip comments and white space
    $aline =~ s/^\s+|\s+$//g; # Remove leading/trailing white space
    $users{$aline} = '0';
} # end of while user input
close USERS;


GROUP_INPUT:
while ($aline = <ETC_GROUP>) {
    chomp($aline);
    if ( $aline =~ m/^(\w+):.*?\d+:(.*)$/ ) {
        my $group_name    = "$1";
        my $group_members = "$2";
        next GROUP_INPUT unless ( "$group_members" );
        #warn "GN = ~$group_name~\tGM = ~$group_members~\n";
        foreach my $user (sort keys %users) {
            #warn "GN = ~$group_name~\tuser = ~$user~\tGM = ~$group_members~\n";
            if ( $group_members =~ m/$user/ ) {
                $group{$group_name}++;                # Count hits
                $members_of{$group_name} .= "$user,"; # Track members
            }
        } # end of user check
    } # end if group record
} # end of while group input
close ETC_GROUP;


# Add missing members, remove any records with zero hits
foreach my $group_name ( keys %group) {
    if ( $group{$group_name} < 1 ) {
        # No hits from our user list; nuke it
        delete $group{$group_name};
        next;
    }
    $missing_from{$group_name} = '';
    foreach my $user (sort keys %users) {
        # Make a list of missing users
        if ( $members_of{$group_name} !~ m/$user/ ) {
            $missing_from{$group_name} .= "$user,";  # Track missing users
        }
    } # end of missing user check
} # end of add missing, remove zeros


# Report
print "MbrCnt\tGroup\tMembers\tMissing\n";
foreach my $group_name (sort { $group{$b} <=> $group{$a} } keys %group) {
    print "$group{$group_name}\t$group_name\t$members_of{$group_name}"
      . "\t$missing_from{$group_name}\n";
} # end of foreach output
