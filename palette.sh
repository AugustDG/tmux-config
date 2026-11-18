#!/bin/sh
# Command palette: fuzzy-pick an entry from palette.tsv or a session to switch
# to. The pick goes into @palette_cmd; the tmux binding runs it once the popup
# has closed.
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

{
    grep -v -e '^#' -e '^$' "$dir/palette.tsv"
    tmux list-sessions -F 'Switch to #{session_name}	switch-client -t "=#{session_name}"'
} | fzf --reverse --no-info --no-sort --prompt '> ' --delimiter "$(printf '\t')" --with-nth 1 |
    cut -f2- |
    {
        IFS= read -r cmd && tmux set-option -g @palette_cmd "$cmd"
    }
