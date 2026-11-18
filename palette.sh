#!/bin/sh
# Command palette: fuzzy-pick an entry from palette.tsv or a session to switch
# to. Entries stay grouped by category; categories are ordered by their total
# picks and entries within one by their own. The pick goes into @palette_cmd;
# the tmux binding runs it once the popup has closed.
#
# `palette.sh tap` records a key press and exits 0 when it lands within 400ms
# of the previous one, so the binding can open the palette on a double tap.
dir=$(dirname "$0")

if [ "$1" = tap ]; then
    now=$(perl -MTime::HiRes=time -e 'printf "%d", time * 1000')
    last=$(tmux show-option -gqv @palette_tap)
    if [ -n "$last" ] && [ $((now - last)) -lt 400 ]; then
        tmux set-option -gu @palette_tap
        exit 0
    fi
    tmux set-option -g @palette_tap "$now"
    exit 1
fi

usage="${XDG_STATE_HOME:-$HOME/.local/state}/tmux/palette-usage"
tab=$(printf '\t')
mkdir -p "$(dirname "$usage")"
touch "$usage"

# input: category, label, command; output: display, label, command, sorted by
# category total, category order, entry count, entry order
pick=$(
    {
        grep -v -e '^#' -e '^$' "$dir/palette.tsv"
        tmux list-sessions -F 'session	Switch to #{session_name}	switch-client -t "=#{session_name}"'
    } |
        awk -F '\t' -v OFS='\t' '
            FILENAME != "-" { n[$1] = $2; next }
            {
                if (!($1 in first)) first[$1] = FNR
                total[$1] += n[$2]
                cat[FNR] = $1; label[FNR] = $2; cmd[FNR] = $3
            }
            END {
                for (i = 1; i <= FNR; i++) {
                    c = cat[i]
                    display = sprintf("\033[2m%-8s\033[0m %s", c, label[i])
                    print total[c], first[c], n[label[i]] + 0, i, display, label[i], cmd[i]
                }
            }' "$usage" - |
        sort -t "$tab" -k1,1nr -k2,2n -k3,3nr -k4,4n |
        cut -f5- |
        fzf --ansi --reverse --no-info --no-sort --prompt '> ' --delimiter "$tab" --with-nth 1
) && [ -n "$pick" ] || exit 0

label=$(printf '%s' "$pick" | cut -f2)
awk -F '\t' -v OFS='\t' -v l="$label" '$1 == l { $2++; found = 1 } { print } END { if (!found) print l, 1 }' "$usage" >"$usage.tmp" &&
    mv "$usage.tmp" "$usage"

tmux set-option -g @palette_cmd "$(printf '%s' "$pick" | cut -f3-)"
