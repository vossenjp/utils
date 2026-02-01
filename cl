#!/bin/bash -
# cl--Clean Up script
# $Id: cl 2243 2026-01-31 21:50:00Z root $
# Requires many other tools: xsel, Perl, Python, pandoc, column, zim2wiki.pl,
# awk, cat, cut, date, egrep, grep, head, rm, scp, sed, sort, tail, tee

WORK_INCLUDE_FILE='/home/jp/bin/cl-include.lib'

if [ -r "$WORK_INCLUDE_FILE" ]; then
    HELP_FILES="$0 $WORK_INCLUDE_FILE"
else
    HELP_FILES="$0"
fi

if [ "$1" == '-h' -o "$1" == 'h' -o "$1" == '--help' -o "$1" == 'help' ]; then
    cat <<-EoN

	Trivial Clean Up script
	    usage: $0 (pipe*) (<action>) (<option or argument>)
	e.g.
	    $0 -h <term>                 # Display actions
	    $0 <action> (<opt/arg>)      # Read/write the clipboard
	    $0 pipe <action> (<o/a>)     # Read STDIN, write STDOUT
	    $0 pipein <action> (<o/a>)   # Read STDIN, write the clipboard
	    $0 pipeout <action> (<o/a>)  # Read the clipboard, write STDOUT

	The usual use-case is reading from then writing to the clipboard, but
	sometimes you want to process files in a pipeline, so in that case use
	'pipe*' to read from STDIN then write to STDOUT or some combination.
	There are a few recursive calls that won't work with 'pipe*'.

	Actions:
	EoN
    grep -h '^    ###' $HELP_FILES | cut -c9- | grep -i "${2:-.}"
    echo ''
    exit 0
fi

# Figure out the input/output tool needed to read/write the clipboard...
if   [ -x /usr/bin/xsel ]; then
    GETCLIP='/usr/bin/xsel -b'
    PUTCLIP='/usr/bin/xsel -bi'
elif [ -x /usr/bin/pbpaste ]; then
    GETCLIP='/usr/bin/pbpaste'
    PUTCLIP='/usr/bin/pbcopy'
else
    echo "Can't find 'xsel' (Linux) or 'pbpaste/pbcopy' (Mac), please install one or the other."
fi

# Then maybe change input/output
if   [ "$1" == 'pipe' ]; then       # Read STDIN, write STDOUT
    GETCLIP='cat'
    PUTCLIP='cat'
    shift
elif [ "$1" == 'pipein' ]; then     # Read STDIN, write the clipboard
    GETCLIP='cat'
    shift
elif [ "$1" == 'pipeout' ]; then    # Read the clipboard, write STDOUT
    PUTCLIP='cat'
    shift
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

    ### T         = Transform using 's/  +/\t/g' (see also 's2t')
    T       ) $GETCLIP | perl -pe 's/  +/\t/g;' | $PUTCLIP ;;

    ### p         = Prefix all lines with '* ' or argument (see also 'bul')
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

    ### bul       = Add a bullet (*) after indent but before text (see also 'p')
    # Replace Unicode bullet (e2 80 a2) with * for wikis
    bul     ) $GETCLIP | perl -pe 's/\xe2\x80\xa2/*/g; s/^(\s*)([[\w]+)/$1* $2/;' | $PUTCLIP ;;

    ### num       = Add a wiki number (#) after indent but before text; replaces static /\d*[.:)\s]*/
    num     ) $GETCLIP | perl -pe 's/^(\s*)\d*[.:)\s]*(.?\w+)/$1# $2/;' | $PUTCLIP ;;

    ### snum      = Statically number lines (not already numbered)
    snum    ) $GETCLIP | perl -pe 's/^/++$i . q(. )/eg;' | $PUTCLIP ;;

    ### renum     = Statically re-number already numbered lines matching /^\d+[.:]? /
    renum   ) $GETCLIP | perl -pe 's/^\d+[.:]? /++$i . q(. )/eg;' | $PUTCLIP ;;

    ### comment   = Prefix line with "# "
    comment ) $GETCLIP | perl -pe 's/^/# /;' | $PUTCLIP ;;

    ### uncomment = Removing leading /^# */
    uncomment ) $GETCLIP | perl -pe 's/^# *//;' | $PUTCLIP ;;

    ### t2s       = Tab2Spaces, default is 1 tab to 4 spaces
    t2s     )
        spaces="${2:-4}"               # Default is '4'
        $GETCLIP | perl -pe "s/\t/' ' x $spaces/ge;" | $PUTCLIP
    ;;
    ### s2t       = Space(s)2Tab, default is 4 spaces to 1 tab (see also 'T')
    s2t     )
        spaces="${2:-4}"               # Default is '4'
        $GETCLIP | perl -pe "s/ {$spaces}/\t/g;" | $PUTCLIP
    ;;

    ### c2t       = CSV2tab
    c2t|csv2tab )  # Python one-liner!  (Also in bashrc for aliases)
        $GETCLIP \
          | python -c "import csv, sys; csv.writer(sys.stdout, delimiter='\t', lineterminator='\n').writerows(csv.reader(sys.stdin))" \
          | $PUTCLIP
    ;;
    ### t2c       = tab2CSV
    t2c|tab2csv )  # Python one-liner!  (Also in bashrc for aliases)
        $GETCLIP \
          | python -c "import csv, sys; csv.writer(sys.stdout, lineterminator='\n').writerows(csv.reader(sys.stdin, delimiter='\t'))" \
          | $PUTCLIP
    ;;

    ### c2j       = CSV2JSON (optionally "pretty")
    c2j|csv2json )  # Python one-liner!  (Also in bashrc for aliases)
        if [ "$2" == 'pretty' ]; then pretty=', indent=2'; else pretty=''; fi
        $GETCLIP \
          | python -c "import csv, json, sys; print(json.dumps(list(csv.reader(sys.stdin))$pretty))" \
          | $PUTCLIP
    ;;
    ### t2j       = tab2JSON (optionally "pretty")
    t2j|tab2json )  # Python one-liner!  (Also in bashrc for aliases)
        if [ "$2" == 'pretty' ]; then pretty=', indent=2'; else pretty=''; fi
        $GETCLIP \
          | python -c "import csv, json, sys; print(json.dumps(list(csv.reader(sys.stdin, delimiter='\t'))$pretty))" \
          | $PUTCLIP
    ;;

    ### dos2unix  = dos2unix (CRLF to LF) using Perl
    dos2unix ) $GETCLIP | perl -pe 's/\r$//'    | $PUTCLIP ;;
    ### unix2dos  = unix2dos (LF to CRLF) using Perl
    unix2dos ) $GETCLIP | perl -pe 's/\n/\r\n/' | $PUTCLIP ;;

    ### r|sort    = Sort
    r|sort  ) $GETCLIP | sort | $PUTCLIP ;;

    ### u|sortu   = Sort | Uniq
    u|sortu ) $GETCLIP | sort | uniq | $PUTCLIP ;;

    ### sortn     = Sort by (leading) numbers
    sortn   ) $GETCLIP | sort -n | $PUTCLIP ;;

    ### sortnu    = Sort by (leading) numbers | Uniq
    sortnu  ) $GETCLIP | sort -n | uniq | $PUTCLIP ;;

    ### sortip    = Sort by (leading) IPA
    # -V is a lot easier than: sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n
    sortip* ) $GETCLIP | sort -V | $PUTCLIP ;;

    ### sortipu   = Sort by (leading) IPA | Uniq
    sortipu ) $GETCLIP | sort -V | uniq | $PUTCLIP ;;

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

    ### pre       = Wrap in Redmine: <pre></pre>
    pre     ) echo -e "<pre>\n$($GETCLIP)\n</pre>" | $PUTCLIP ;;

    ### c         = Wrap in Redmine: <pre><code class="<TYPE>">...</code></pre>
    c       )
        type="${2:-bash}"               # Default is 'bash'
        echo -e "<pre><code class=\"$type\">\n$($GETCLIP)\n</code></pre>" | $PUTCLIP
    ;;

    ### col       = Wrap in Redmine {{Collapse...}} macro (no 'pipe*)
    col     )
        $0 c $2  # Recursive call won't work with pipe*
        echo -e "{{Collapse(...)\n$($GETCLIP)\n}}" | $PUTCLIP
    ;;

    ### code|jc   = Wrap in Jira {code:<TYPE>}..{code} macros
    code|jc )
        type="${2:-bash}"               # Default is 'bash'
        echo -e "{code:$type}\n$($GETCLIP)\n{code}\n" | $PUTCLIP
    ;;

    ### table     = Turn a TAB delimited table into a Redmine wiki table
    table   ) $GETCLIP > /tmp/table
              head -n1  /tmp/table | perl -pe 's/\t/ |_. /g; s/^/|_. /; s/$/ |/;'  > /tmp/table2
              tail -n+2 /tmp/table | perl -pe 's/\t/ | /g;   s/^/| /;   s/$/ |/;' >> /tmp/table2
              sed 's/|/\&|/g' /tmp/table2 | column -t -s'\&' \
                | perl -pe 's/  \|/|/g;' | $PUTCLIP
              rm -f /tmp/table /tmp/table2
    ;;

    ### mtable    = Turn a TAB delimited table into a Markdown table
    mtable  ) $GETCLIP > /tmp/table
              head -n1  /tmp/table  | perl -pe 's/\t/ | /g; s/^/| /; s/$/ |/;'      > /tmp/table2
              head -n1  /tmp/table2 | perl -pe 's/[^|]/-/g; s/-$/\n/;'             >> /tmp/table2
              tail -n+2 /tmp/table  | perl -pe 's/\t/ | /g;   s/^/| /;   s/$/ |/;' >> /tmp/table2
              sed 's/|/\&|/g' /tmp/table2 | column -t -s'\&' \
                | perl -pe 's/  \|/|/g;' | $PUTCLIP
              rm -f /tmp/table /tmp/table2
    ;;

    ### jtable    = Turn a TAB delimited table into a Jira wiki table
    jtable  )  # Same as a Redmine table except change header "|_." to "||" (no 'pipe*)
        $0 table  # Recursive call won't work with pipe*
        $GETCLIP | perl -pe 's/\|_\./ ||/g;' -e 's/^ \|\| /|| /;' \
          | $PUTCLIP
    ;;

    ### r2j       = Convert Redmine @/<pre><code... tags to Jira {{/{code}
    r2j      ) $GETCLIP | perl -p \
                 -e 's/^> /bq. /g;' \
                 -e 's/\B@(\S)/{{$1/g;' \
                 -e 's/(\S)@\B/$1}}/g;' \
                 -e 's/<pre><code class="(\w+)">/{code:$1}/g;' \
                 -e 's/<pre>/{code:bash}/g;' \
                 -e 's!(</code>)?</pre>!{code}!g;' \
                 -e 's/"([^"]+)":(http\S+)/[$1|$2]/g;' \
                 | $PUTCLIP
    ;;

    ### j2r       = Convert Jira {{/{code} tags to Redmine @/<pre><code...
    j2r      ) $GETCLIP | perl -p \
                 -e 's/^bq\. /> /g;' \
                 -e 's/\B\{\{(\S)/\@$1/g;' \
                 -e 's/(\S)\}\}\B/$1@/g;' \
                 -e 's/\{code:(\w+)\}/<pre><code class="$1">/g;' \
                 -e 's!\{code\}!</code></pre>!g;' \
                 -e 's!\{noformat\}!</pre>!g;' \
                 -e 's/\[(.*?)\|(.*?)\]/"$1":$2/g;' \
                 -e 's/\{color:(#\w+)\}/%{color:\1}/g;' \
                 -e 's/\{color\}/%/g;' \
                 | $PUTCLIP
    ;;

    ### j2z       = Convert Jira to Zim using Pandoc...
    j2z      ) $GETCLIP | pandoc --from Jira --to ZimWiki | $PUTCLIP ;;

    # Fix the insane CRAP Jira adds when you paste an OL email!
    ### j2t       = Convert Jira to text by removing CR, 2NBSP (\xC2A0), 3x \n, and 1 leading space
    # Third line is a slurp, could use `perl -o -pe` too
    j2t     ) $GETCLIP | perl -pe 's/\r$//' \
                       | perl -pe 's/\xc2\xa0//g;' \
                       | perl -pe 'undef $/; s/\n\n\n/\n/g;' \
                       | perl -pe 's/^\s(\S)/\1/g;' | $PUTCLIP ;;

    ### r2z       = Convert Redmine/Textile to Zim using Pandoc
    r2z     )
        # Pandoc outputs "https:''//''" for some reason, so fix that
        $GETCLIP | pandoc --from textile --to ZimWiki \
          | perl -pe "s!(https?):''//''!\1://!g;" \
          | $PUTCLIP
    ;;

    ### z2r       = Convert Zim to Redmine markup
    z2r     ) $GETCLIP | zim2wiki.pl | $PUTCLIP ;;

    ### z2j       = Convert Zim to Jira markup
    z2j     )
        $GETCLIP | zim2wiki.pl | $PUTCLIP  # Zim to Redmine
        $0 r2j                             # Redmine to Jira
    ;;

    ### z2m       = Convert Zim to Mediawiki markup
    z2m     ) $GETCLIP | zim2wiki.pl -m | $PUTCLIP ;;

    ### z2h       = Convert Zim to HTML using Pandoc, to ~/SHARED/temp.html Webtop file
    z2h     )
        # Pandoc can't handle Zim checkboxes, so convert to bullets
        $GETCLIP | zim2wiki.pl | perl -pe 's/^\t//; s/\[.\]/*/;' \
          | pandoc --from textile --to html > ~/SHARED/temp.html
        echo "Don't forget to 'Copy As...Wiki'!"
        echo 'On VM side:     firefox ~/SHARED/temp.html'
        echo 'On Webtop side: explorer "OneDrive - BT Plc\Documents\SHARED\temp.html"'
    ;;

    ### recap     = Convert an Ansible "RECAP" to a Jira list (j2r to convert)
    # See also `recap` script
    recap   ) $GETCLIP | perl -p \
                -e 's/\s+$/\n/;' \
                -e 's/^(\w+.*? unreachable=1 .*)$/-{color:#FF0000}{{\1}}{color}- < unreachable/;' \
                -e 's/^(\w+.*? failed=1.*)$/-{color:#B22222}{{\1}}{color}- < failed/;' \
                -e 's/^(\w+.*? changed=[^0].*)$/{color:#FFA500}{{\1}}{color}/;' \
                -e 's/^(\w+.*)$/{color:#008000}{{\1}}{color}/;' \
                -e 's/^/# /;' \
                | sort | $PUTCLIP
    ;;
    # This is pretty ugly, but...it works
    # Trim useless trailing white space
    # Unreachable = -{{...}}- < unreachable  Red
    # Failed      = -{{...}}- < failed       FireBrick
    # Changed     = {{...}}                  Orange
    # Otherwise   = {{...}}                  Green
    # Add leading "# "
    #
    # My line colors                          Ansible ANSI color   Field
    # {color:#FF0000}Red{color}               31m red              Unreachable
    # {color:#B22222}FireBrick (Red){color}   31m red              Failed
    # {color:#FFA500}Orange{color}            33m yellow           Changed
    # {color:#008000}Green{color}             32m green            OK
    # Didn't do Cyan for skipped              36m cyan             Skipped
    # Changed is yellow in Ansible, but that's unreadable in my Jira testing
    # I used different colors for unreachable vs. failed

    ### call      = Wrap text into Zim "call" note
    call )  echo -e "\t[ ] **Call: ? min $($GETCLIP)**" | $PUTCLIP ;;

    ### url       = Remove trash (e.g, "safelink", "\?.*$") & un-escape %nn from a URL
    url     ) $GETCLIP | perl -pe 's/\%(\w\w)/chr hex $1/ge;' \
                -e 's!https?://.*?\.safelinks\.protection\.outlook\.com/\?url=!!;' \
                -e 's/&amp;/&/g;' \
                -e 's/&data=\d+\|\d+\|.+?\@\w+\.com.*$//;' \
                | $PUTCLIP
    ;;
              # See https://unix.stackexchange.com/a/159309 for URL unescape
              # This is more readable but needs a module:
              # perl -MURI::Escape -e 'print uri_unescape($ARGV[0])' "$encoded_url")
              # This doesn't work:
              # perl -MHTML::Entities -pe 'decode_entities($_)'
              # In Bash you can replace % with \x the decode HEX, but it's tricky
              # https://stackoverflow.com/a/42636717, https://github.com/sixarm/urldecode.sh

    ### furl      = Remove MORE URL trash (e.g, Full, 's/[?&]\S+(\s*)//') (no 'pipe*)
    furl|urlf )
        $0 url  # Recursive call won't work with pipe*
        $GETCLIP | perl -pe 's!(https?://.*?)[?&]\S+(\s*)!$1$2!g;' | $PUTCLIP
    ;;

    ### az        = Remove Amazon 'ref.*$' trash/tracking
    az|amazon )
        $GETCLIP | perl -pe 's!/ref.*$!/!g;' | $PUTCLIP
    ;;

    ### em|ol     = Process copy&paste from Outlook Sent Mail
    em|ol   ) $GETCLIP | emm.pl | $PUTCLIP ;;
              # See '...Pub/util/CIS/emm.pl'.  Brute-force:
                # $GETCLIP | cut -f2 | sort -u | grep -v '^Subject$' \
                #  | perl -ne 'chomp(); print qq(>EM "$_"\n);' | $PUTCLIP ;;

    ### sent      = Add a '{date} >EM "test"' wrapper around input
    sent|send ) printf "%(%F %a)T >EM \"%s\"\n" '-1' "$($GETCLIP)" | $PUTCLIP ;;

    ### days (n)  = Print the next n days (18 is default) to the screen and /tmp/days
    days    ) for day in $(seq 0 ${2:-18}); do date -d "+ $day day" '+%Y-%m-%d %a:'; done | tee /tmp/days ;;

    ### opsview   = Convert Opsview warnings/critical matrix to table
    opsview ) $GETCLIP | opsview-to-table.pl | $PUTCLIP ;;

    ### bp|sgp    = Same as "x" but also remove trailing "-?b_id=NNNN" or "-" (no 'pipe*)
    bp|sgp  )
        $0 x  # Recursive call won't work with pipe*
        $GETCLIP | perl -pe 's/-\?b_id=\d+$//; s/-$//;' | $PUTCLIP
    ;;

    ### *         = Trim leading and/or trailing white space
    *       )
        if [ -r "$WORK_INCLUDE_FILE" ]; then
            source "$WORK_INCLUDE_FILE"
        else
            $GETCLIP | perl -pe 's/^\s+//; s/\s+$/\n/;' | $PUTCLIP
        fi
    ;;

esac
