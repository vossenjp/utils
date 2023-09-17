#!/bin/bash -
# Save/Restore FF sessions
# $Id: ff-sess.sh 2186 2021-11-21 21:38:08Z root $

# # Twice daily FF session backup
# 45 03,15 * * * opt/bin/ff-sess.sh qsave

# DOCS:
# https://support.mozilla.org/en-US/questions/1247052
# To recover: cp <profile>/sessionstore-backups/previous.jsonlz4 <profile>/sessionstore.jsonlz4
# NOTES:
# /home/*/.mozilla/firefox/*/sessionstore-backups:
# recovery.jsonlz4: the windows and tabs in your currently live Firefox session (or, if Firefox crashed at the last shutdown and is still closed, your last session)
# recovery.baklz4: a backup copy of recovery.jsonlz4
# previous.jsonlz4: the windows and tabs in your last Firefox session
# upgrade.jsonlz4-build_id: the windows and tabs in the Firefox session that was live at the time of your last update
# various .js files from Firefox 55 or earlier
#
# To read the asinine *.jsonlz4, install python-lz4 and see /opt/bin/mozlz4
#
# OLD DOCS:
# https://dutherenverseauborddelatable.wordpress.com/2014/06/26/firefox-the-browser-that-has-your-backup/
    # sessionstore.js (contains the state of Firefox during the latest shutdown – this file is absent in case of crash);
    # sessionstore-backups/recovery.js (contains the state of Firefox ≤ 15 seconds before the latest shutdown or crash – the file is absent in case of clean shutdown, if privacy settings instruct us to wipe it during shutdown, and after the write to sessionstore.js has returned);
    # sessionstore-backups/recovery.bak (contains the state of Firefox ≤ 30 seconds before the latest shutdown or crash – the file is absent in case of clean shutdown, if privacy settings instruct us to wipe it during shutdown, and after the removal of sessionstore-backups/recovery.js has returned);
    # sessionstore-backups/previous.js (contains the state of Firefox during the previous successful shutdown);
    # sessionstore-backups/upgrade.js-[build id] (contains the state of Firefox after your latest upgrade).

# See also:
    # http://kb.mozillazine.org/Session_Restore
        # about:sessionrestore
    # https://wiki.mozilla.org/Session_Restore

date=$(date '+%a_%H')

case "$1" in
    qsave    )  # Quiet save, unless there are errors
        cd $HOME/.mozilla/firefox
        rm -f ff_sessions_$date.zip
        zip -9qr ff_sessions_$date.zip */session*

        # Sanity check that the latest restore files really exist!
        # I have no idea what to do if they don't though...  And yes, we
        # already created the tarball, better to have some of it anyway...
        for dir in $(ls -1d */session* | cut -d '/' -f1 | sort -u); do
            [ -d "$dir" ] || continue  # Just in case
            [ -d "$dir/sessionstore-backups/" ] \
              || mkdir -pv "$dir/sessionstore-backups"  # Just FIX it!
              #|| echo "WARNING: '$HOME/.mozilla/firefox/$dir/sessionstore-backups/' missing!"
            [ -f "$dir/sessionstore-backups/recovery.jsonlz4" ] \
              || echo "WARNING: '$HOME/.mozilla/firefox/$dir/sessionstore-backups/recovery.jsonlz4' missing!"
        done
    ;;

    save    )  # Noisy save (calls qsave)
        echo "SAVING session data into '$date' file"
        $0 qsave
    ;;

    restore )
        [ -z "$2" ] && { echo "Need a date to restore from!"; exit 1; }
        date="$2"
        echo "Restoring session data from '$date' file"
        cd $HOME/.mozilla/firefox
#        killall firefox
        unzip -o ff_sessions_$date.zip
    ;;

    menu )
        # `dialog` values
        HEIGHT='23'
        WIDTH='30'
        CHOICE_HEIGHT='14'
        TITLE='Firefox Tab Restore'
        BACKTITLE="$TITLE"
        MENU="Choose a backup to restore:"

        IFS=$'\n\t'  # Don't parse on spaces; DO need tabs and newlines
        OPTIONS=(
          $(\ls -hltr $HOME/.mozilla/firefox/ff_sessions_* \
           | perl -pe 's!^.*?(\w{3} [\d: ]*?) /home/.*?/.mozilla/firefox/ff_sessions_(\w{3}_\d{2}).zip$!\2\t\1!;')
        )

        # Display the menu
        backup=$(dialog --clear --backtitle "$BACKTITLE" --title "$TITLE" \
                        --menu "$MENU" $HEIGHT $WIDTH $CHOICE_HEIGHT \
                        "${OPTIONS[@]}" 2>&1 >/dev/tty)

        # Regex match "Mon_03" to make sure we don't kill FF on a parsing error
        [[ "$backup" =~ ^[MTWFS][a-z]{2}_[0-9]{2}$ ]] && {
            echo "Restoring '$backup'..."
            $0 restore $backup
        }
    ;;

    *       )
        echo 'Save/Restore FF sessions'
        echo "$0 save"
        echo "$0 menu       # Displays a menu of files to restore"
        echo "$0 restore <date>"
        echo "    e.g., $0 restore Wed_15"
        echo ''
        echo 'NOTE: the "menu" or "restore" options will KILL all running Firefox windows!'
    ;;
esac
