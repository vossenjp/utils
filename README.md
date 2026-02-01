# utils
Various useful utils and bash settings

**Do not run any of this code without reading and understand it!**

## Introduction

This is the "local" code I sync to all the nodes I manage.  Some of it is not production quality and I wrote some of it decades ago, so there may be better ways or better tools.  But it's what I have.  I share it in case it's useful to someone else.  Some of the ideas may have come out of the _Bash Cookbook_ but some of them went into it.  Some of the code came right off the internet, and some was adapted; either should be cited.

I sync it to `/opt/bin/` because that's reasonably discoverable and short, system-wide, yet distinct from `/usr/local/bin/` or similar.  I keep it in Subversion because I like keyword expansion and do not like Git, so I use both `svn` and `git` together to only publish what I want to here.

Some of the code or settings might make sense only to me or my environment, so **read** the code first.  In particular, `drake` is my internal "services" server and `hamilton` is my mail relay, both are references to authors I like, and not musical.  Also, there might be code derived from or handlers for $WORK things, in particular Counterpane (CIS).  Since that tech is now defunct I'm not going to worry too much.


## Installing

Just clone the repo someplace and use whichever files you want.  Do not run any of this code without reading and understand it!


## Use

1. Try `<PROGRAM> -h` or `<PROGRAM> --help` (works for most, but not all!)
2. Read the code


## List

The **`cl`** "clean Up script" is probably the most handy tool I have.  It's a filter that reads from the GUI clipboard, does some arbitrary thing, then writes the results back to the GUI clipboard.  It does almost _all the things_ for me but it's an odd work-flow.  I like it because I can make it to arbitrary things using bash or Perl one-liners, and I'm not stuck with 37 different macro languages.  Whatever GUI tool I happen to be using: select > copy > ALT-TAB to terminal > `cl whatever` > ALT-TAB back > paste.


### Tools:

* `DNSlookup.pl` Lookup IPAs and get hostnames
* `addheader` Add a header at the top of an existing file (very old, arguably crufty and overkill)
* `addlt` Add line termination to "one line" HTML files
* `benford.sh` Write a Benford's Law histogram from input (in pure bash)
* `caps2esc` Map "caps lock" to "Esc" and back (From http://www.linuxquestions.org/questions/linux-general-1/vim-map-caps-lock-to-escape-409726)
* `changelog` Trivial system CHANGELOG wrapper to maintain a `/root/CHANGELOG.txt` (crufty style)
* `chperm` Set owner.group and mode/permissions on a given file in 1 step
* `cl` **Clean Up script**, most wiki markup is Zim syntax, but there is Redmine and Jira in there too and some features require `pandoc` or other external tools
* `colors` Echo color codes to the screen to see what works (http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/x329.html)
* `deb` wrapper/reminder for various apt* and dpkg commands
* `disk-and-partitions` Collect data on disks and partitions, just to have
* `domath.pl` Perform math operations on arbitrary lines of numerical input
* `editable_menu_shortcuts` Turn Gnome editable menu shortcuts on and off (Obsolete?)
* `ff-sess.sh` Save/Restore FF sessions, with trivial restore GUI (CLI, using `dialog`)
* `find-group.pl` Find a group containing the most users from a `users.txt` list; useful when considering creating a new groups, to see if you might already have a group containing most of the users
* `findlarge` Trivial reminder/skeleton for finding "large" files in various locations
* `findz` Find Zombie processes and parent PID
* `fixbadsig` Fix BADSIG and other crap in APT repos data (Obsolete?)
* `foreground` Bring a named window to the foreground in a GUI, else run it (map it to a keystroke in a GUI)
* `linesort` Trivial in-line sort (sort delimited items within a single line, see also `cl`)
* `mksshconf` Trivial script to make ~/.ssh/config file since you can't #INCLUDE
* `mount-iso` Trivial wrapper to mount an ISO image
* `pd` Trivial Pandoc Markdown to HTML or PDF wrapper
* `pick-one.sh` Randomly choose from a list of options
* `pivot-by-date.pl` Pivot "Count | Date | Key" columnar data by date and key
* `pivot-key-value.pl` Pivot a key and a value column into a matrix
* `pivot-key-values.py` Pivot a key and a comma delimited value column into a matrix
* `pivot.pl` Pivot cells (e.g. columns to rows) in a table
* `remote-desktop` Fire up a remote desktop session on the remote side (1-time only, no SSH)
* `read-maillog.pl` Read 'mail.log' files written by Postfix and report details (quite crufty with hard-coded server names!)
* `rhythmbox-ratings.pl` Merge "old" ratings into a new Rhythmbox XML file
* `rhythmbox-rm-badpath.pl` Remove duplicate records with bad path from Rhythmbox XML file
* `rot13.pl` Guess...
* `rot47.pl` Guess...
* `ruler.sh` Display a "ruler" across the screen
* `sample.pl` Sample a log file to create a smaller file
* `saveperms` Save permissions for a directory structure
* `show_package_updates` Trivially check for new packages on a Debian-ish system (run from cron, somewhat crufty and experimental)
* `star.pl` Replace various strings with star "*" to allow use of 'uniq' and other tools (old, crufty, some old CIS bits)
* `split-up.sh` Split up a file by writing alternating lines to different files
* `srpmx` Extract files from a source RPM (requires `rpm2cpio` binary, find that elsewhere)
* `sshfsw` Trivial SSHFS wrapper (SSH File System = FUSE = Awesome!)
* `sysstat` Display some system stats (e.g. run from cron periodically) (Obsolete?  Probably lots of better tools out there!)
* `tattle` Log the way this program was called; useful for tracing remote commands such as rsync over SSH.
* `tz` Trivial script to convert time zones using GNU `date`
* `untar` Simple (GNU) tar wrapper
* `waitfor` Like `sleep` except for a random integer period in an arbitrary range
* `whatdeb` (or `whatrpm`) Quick and Dirty find for installed RPMs or DEBs
* `zim2wiki.pl` Trivially convert Zim markup to Redmine or Mediawiki


### Settings:

These are the settings or configs that I use everywhere, every day.

* `settings/README` Quick summary of bash init and rc files
* `settings/bash_logout` Clear the screen on logout to prevent information leaks
* `settings/bash_profile` Login shell environment settings
* `settings/bashrc` Subshell environment settings
* `settings/gitconfig` My typical Git config
* `settings/inputrc` readline settings
* `settings/panam-styling-include.css` "Fancy CSS" for use with Pandoc `pd` wrapper
* `settings/run_screen` Wrapper script intended to run from a "profile" file to run screen at logon time with a friendly menu
* `settings/screenrc` Screen RC file
* `settings/vimrc` VIM RC file


### Special & Dangerous

*Do not run any of this code without reading and understand it!*  These can trash your hard drives and destroy all your data!  They worked for me, for how *I* set things up and how *I* do things.  Do not run these without understanding exactly what they do and modifying them to fit your environment!  You have been warned.

* `grow_mirrored_disk` Grow a Linux software mirror after swapping in larger hard drives
* `replace_mirrored_disk` Replace a failed disk in a Linux software mirror
