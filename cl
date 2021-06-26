#!/bin/bash -
# cl--Clean Up script

if [ "$1" = '-h' -o "$1" = '--help' -o "$1" = 'help' ]; then
    cat <<-EoN

	Trivial Clean Up script
	    usage: $0 ({option})
	e.g.
	    usage: $0 -h <term>
	    usage: $0 x

	Options:
	EoN
    grep '^    ###' $0 | cut -c9- | grep -i "${2:-.}"
    echo ''
    exit 0
fi

# Figure out the tool needed...
if   [ -x /usr/bin/xsel ]; then
    GETCLIP='/usr/bin/xsel -b'
    PUTCLIP='/usr/bin/xsel -bi'
elif [ -x /usr/bin/pbpaste ]; then
    GETCLIP='/usr/bin/pbpaste'
    PUTCLIP='/usr/bin/pbcopy'
else
    echo "Can't find 'xsel' (Linux) or 'pbpaste/pbcopy' (Mac), please install one or the other."
fi

    #   cmd )     = desc    <<< template

case "$1" in
    ### a|b|1|0   = Trim leading white space
    a|b|1|0 ) $GETCLIP | perl -pe 's/^\s+//;' | $PUTCLIP ;;

    ### e|2       = Trim trailing white space
    e|2     ) $GETCLIP | perl -pe 's/\s+$/\n/;' | $PUTCLIP ;;

    ### x         = Trim leading/trailing white space and leading \d#*+~
    x       ) $GETCLIP | perl -pe 's/^[\[\]>\s\d#*+~]+//; s/\s+$/\n/;' | $PUTCLIP ;;

    ### s         = Change all double-spaces to a single space
    s       ) $GETCLIP | perl -pe 's/  / /g;' | $PUTCLIP ;;

    ### S         = Change all \n\s*\n to \n
    # Slurp, could use `perl -o -pe` too
    S       ) $GETCLIP | perl -pe 'undef $/; s/\n\s*\n/\n/g;' | $PUTCLIP ;;

    ### uc        = Change line to upper case
    uc      ) $GETCLIP | perl -ne 'print uc();' | $PUTCLIP ;;
    ### lc        = Change line to lower case
    lc      ) $GETCLIP | perl -ne 'print lc();' | $PUTCLIP ;;
    ### tc        = Change line to title case
    tc      ) $GETCLIP | perl -pe 's/(\w+)/\u\L$1/g;' | $PUTCLIP ;;

    ### t         = Transform using ARG, e.g., 's/ +/\t/g'
    t       ) $GETCLIP | perl -pe "$2" | $PUTCLIP ;;

    ### T         = Transform using 's/  +/\t/g'
    T       ) $GETCLIP | perl -pe 's/  +/\t/g;' | $PUTCLIP ;;

    ### p         = Prefix all lines with '* ' or argument
    p       )
        prefix="${2:-* }"               # Default is '* '
        $GETCLIP | perl -ne "print qq($prefix\$_);" | $PUTCLIP
    ;;
    ### P         = suffix all lines with argument
    P       )
        suffix="$2"
        $GETCLIP | perl -ne "chomp(); print qq(\${_}$suffix\n);" | $PUTCLIP
    ;;

    ### y         = Yank argument prefix from all lines
    y       )
        prefix="$2"
        $GETCLIP | perl -pe "s/^$prefix//;" | $PUTCLIP
    ;;
    ### Y         = Yank argument suffix from all lines
    Y       )
        suffix="$2"
        $GETCLIP | perl -pe "s/$suffix\$//;" | $PUTCLIP
    ;;

    ### out       = Outdent one outline level (remove 1st [#*\t] char)
    out     ) $GETCLIP | perl -pe 's/^[#*\t]//;' | $PUTCLIP ;;

    ### in        = Indent one outline level (repeat 1st [#*\t] char)
    in      ) $GETCLIP | perl -pe 's/^([#*\t])/$1$1/;' | $PUTCLIP ;;

    ### bul       = Add a bullet (*) after indent but before text
    bul     ) $GETCLIP | perl -pe 's/^(\s*)(\w+)/$1* $2/;' | $PUTCLIP ;;

    ### num       = Number lines (not already numbered)
    num     ) $GETCLIP | perl -pe 's/^/++$i . q(. )/eg;' | $PUTCLIP ;;

    ### renum     = Re-number (already numbered) lines matching /^\d+[.:]? /
    renum   ) $GETCLIP | perl -pe 's/^\d+[.:]? /++$i . q(. )/eg;' | $PUTCLIP ;;

    ### t2s       = Tab2Spaces, default is 1 tab to 4 spaces
    t2s     )
        spaces="${2:-4}"               # Default is '4'
        $GETCLIP | perl -pe "s/\t/' ' x $spaces/ge;" | $PUTCLIP
    ;;
    ### s2t       = Space(s)2Tab, default is 4 spaces to 1 tab
    s2t     )
        spaces="${2:-4}"               # Default is '4'
        $GETCLIP | perl -pe "s/ {$spaces}/\t/g;" | $PUTCLIP
    ;;

    ### r|sort    = Sort
    r|sort  ) $GETCLIP | sort | $PUTCLIP ;;

    ### u|sortu   = Sort | Uniq
    u|sortu ) $GETCLIP | sort | uniq | $PUTCLIP ;;

    ### linesort  = Sort in-line (<delim-in> (<delim-out>))
    # cl linesort ',' ','     # Same as default
    # cl linesort '\s' ' '    # Spaces, note: ' ' won't work
    # BETTER https://stackoverflow.com/questions/8802734/sorting-and-removing-duplicate-words-in-a-line
      # echo $(echo '001 001 002 002' | xargs -n1 | sort -u)
      # echo $(printf '%s\n' 001 001 002 002 | sort -u)
    linesort )
        delimiter_in="${2:-,}"               # Default is ','
        delimiter_out="${3:-$delimiter_in}"  # Default is same as $delimiter_in
        [ "$delimiter_in" == ' ' ] && { delimiter_in='\s'; delimiter_out=' '; }
        # This needs a leading space for some reason I can't figure out, but
        # if you add it you get it in the output too.  So hack around that.
        { echo -n ' '; $GETCLIP; } \
          | perl -a -F"$delimiter_in" -ne "print join('$delimiter_out', sort @F);" \
          | perl -pe 's/^\s+//; s/\s+$/\n/;' | $PUTCLIP
    ;;

    ### ja ...    = Use awk to extract ..., e.g., '$2,$4'
    ja|awk  ) $GETCLIP | awk "{print $2}" | $PUTCLIP ;;

    ### sum       = Sum of space, comma, newline or + delimited numbers
    sum     )
        # "Normalize" then sum up
        $GETCLIP | perl -pe 's/\+|,| /\n/g;' \
          | perl -ne 'chomp(); $total+=$_;' -e 'END { print qq($total\n); }' \
          | $PUTCLIP
    ;;
    ### sums      = Sum of space, comma, newline or + delimited numbers, with input
    sums    )
        # "Normalize" then sum up, but display normalized input too
        # There must be a slicker way than this!
        $GETCLIP | perl -pe 's/\+|,| /\n/g;' \
          | perl -ne 'chomp(); $nums.=qq($_+); $total+=$_;' \
                  -e 'END { chop($nums); print qq($nums = $total\n); }' \
          | $PUTCLIP
    ;;

    ### c         = Wrap in Redmine {{Collapse...}} macro
    c       ) echo -e "{{Collapse(...)\n<pre>\n$($GETCLIP)\n</pre>\n}}" | $PUTCLIP ;;

    ### code      = Wrap in Jira {code:bash}..{code} macros
    code    ) echo -e "{code:bash}\n$($GETCLIP)\n{code}\n" | $PUTCLIP ;;

    ### table     = Turn a TAB delimited table into a Redmine wiki table
    table   ) $GETCLIP > /tmp/table
              head -n1  /tmp/table | perl -pe 's/\t/ |_. /g; s/^/|_. /; s/$/ |/;' > /tmp/table2
              tail -n+2 /tmp/table | perl -pe 's/\t/ | /g; s/^/| /; s/$/ |/;'    >> /tmp/table2
              sed 's/|/\&|/g' /tmp/table2 | column -t -s'\&' | $PUTCLIP
              rm -f /tmp/table /tmp/table2
    ;;

    ### jtable    = Turn a TAB delimited table into a Jira wiki table
    jtable  )  # Same as a Redmine table except change header "|_." to "||"
        $0 table
        $GETCLIP | perl -pe 's/\|_\./ ||/g;' -e 's/^ \|\| /|| /;' \
          | $PUTCLIP
    ;;

    ### r2j       = Convert Redmine @/<pre> tags to Jira {{/{code}
    r2j      ) $GETCLIP | perl -p \
                 -e 's/^> /bq. /g;' \
                 -e 's/\B@(\S)/{{$1/g;' \
                 -e 's/(\S)@\B/$1}}/g;' \
                 -e 's/<pre>/{code:bash}/g;' \
                 -e 's!</pre>!{code}!g;' \
                 -e 's/"([^"]+)":(http\S+)/[$1|$2]/g;' \
                 | $PUTCLIP
    ;;

    ### j2r       = Convert Jira {{/{code} tags to Redmine @/<pre>
    j2r      ) $GETCLIP | perl -p \
                 -e 's/^bq\. /> /g;' \
                 -e 's/\B\{\{(\S)/\@$1/g;' \
                 -e 's/(\S)\}\}\B/$1@/g;' \
                 -e 's/\{code:bash\}/<pre>/g;' \
                 -e 's!\{code\}!</pre>!g;' \
                 -e 's/\[(.*?)\|(.*?)\]/"$1":$2/g;' \
                 | $PUTCLIP
    ;;

    ### r2z       = Convert Redmine/Textile to Zim using Pandoc
    r2z     )
        # Pandoc outputs "https:''//''" for some reason, so fix that
        $GETCLIP | pandoc --from textile --to ZimWiki \
          | perl -pe "s!(https?):''//''!\1://!g;" \
          | $PUTCLIP
    ;;

    ### z2w|z2r   = Convert Zim to Redmine markup
    z2w|z2r ) $GETCLIP | zim2wiki.pl | $PUTCLIP ;;

    ### z2m       = Convert Zim to Mediawiki markup
    z2m     ) $GETCLIP | zim2wiki.pl -m | $PUTCLIP ;;

    ### z2h       = Convert Zim to HTML using Pandoc, to ~/wtmp/temp.html Webtop file
    z2h     )
        # Pandoc can't handle Zim checkboxes, so convert to bullets
        $GETCLIP | perl -pe 's/^\t//; s/\[.\]/*/;' \
          | pandoc --from markdown --to html > ~/wtmp/temp.html
        echo 'On VM side:     firefox ~/wtmp/temp.html'
        echo 'On Webtop side: explorer tmp\temp.html'
    ;;

    ### recap     = Convert an Ansible "RECAP" to a Redmine list (r2j to convert)
    recap   ) $GETCLIP | perl -p \
                 -e 's/\s+$/\n/;' \
                 -e 's/^(\w+.*? unreachable=1 .*)$/-\@\1\@-/;' \
                 -e 's/^(\w+.*? failed=1.*)$/-\@\1\@- < failed/;' \
                 -e 's/^(\w+.*)$/\@\1\@/;' \
                 -e 's/^/# /;' \
                 | $PUTCLIP
    ;;
    # Trim useless trailing white space
    # Unreachable = -@@-
    # Failed      = -@@- < failed
    # Otherwise   = @@
    # Add leading "# "

    ### url       = Remove trash (e.g, "safelink", "\?.*$") & un-escape %nn from a URL
    url     ) $GETCLIP | perl -pe 's/\%(\w\w)/chr hex $1/ge;' \
                -e 's!https?://.*?\.safelinks\.protection\.outlook\.com/\?url=!!;' \
                -e 's/&amp;/&/g;' \
                -e 's/&data=\d+\|01\|.+?\@bt\.com.*$//;' \
                | $PUTCLIP
    ;;
              # See https://unix.stackexchange.com/a/159309 for URL unescape
              # This is more readable but needs a module:
              # perl -MURI::Escape -e 'print uri_unescape($ARGV[0])' "$encoded_url")
              # This doesn't work:
              # perl -MHTML::Entities -pe 'decode_entities($_)'
              # In Bash you can replace % with \x the decode HEX, but it's tricky
              # https://stackoverflow.com/a/42636717, https://github.com/sixarm/urldecode.sh

    ### furl      = Remove MORE URL trash (e.g, Full, 's/[?&]\S+(\s*)//')
    furl|urlf )
        $0 url
        $GETCLIP | perl -pe 's!(https?://.*?)[?&]\S+(\s*)!$1$2!g;' | $PUTCLIP
    ;;

    ### az        = Remove Amazon 'ref.*$' trash/tracking
    az|amazon )
        $GETCLIP | perl -pe 's!/ref.*$!/!g;' | $PUTCLIP
    ;;

    ### *         = Trim leading and/or trailing white space
    *       ) $GETCLIP | perl -pe 's/^\s+//; s/\s+$/\n/;' | $PUTCLIP ;;
esac
