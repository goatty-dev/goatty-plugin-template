# fd plugin for goatty: the optional `fcd` command.
# Sourced in every goatty shell while the "fcd command" setting is on.
# Define functions here; don't run anything slow or print at startup.

# Pick a folder below the current one with fzf and cd into it.
fcd() {
  if (( ! $+commands[fzf] )); then
    print -u2 -r -- "fcd: needs fzf (install it, e.g. goattyd shell install fzf)"
    return 1
  fi
  local dir
  dir=$(fd --type=directory --strip-cwd-prefix "$@" | fzf --height=40% --reverse) && cd -- "$dir"
}
