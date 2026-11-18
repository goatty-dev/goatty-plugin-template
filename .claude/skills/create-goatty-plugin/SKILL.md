---
name: create-goatty-plugin
description: Create or update a goatty plugin (plugin.toml): find pinned release assets with sha256, turn the tool's options into explained settings, wire them through aliases/env/config files/zsh code, declare permissions, and validate with goatty-plugin. Use when asked to make, port, fix or bump a plugin for goatty, or to package a command-line tool for goatty's plugin registry.
---

# Creating a goatty plugin

A goatty plugin is a declarative `plugin.toml` (+ optional zsh files). goatty downloads the tool into its own directory, shows the settings on its Plugins page, and generates shell configuration from the settings. The format reference is goatty's `docs/plugins.md` (https://github.com/goatty-dev/goatty/blob/main/docs/plugins.md); the commented `plugin.toml` in this repository is a complete example (fd).

## Workflow

1. **Understand the tool.** Read its README and `--help`/man page (from the repository, e.g. `gh api repos/OWNER/REPO/contents/doc/...`; don't run downloaded binaries). Note how it's configured: command-line flags, environment variables, a config file (and the variable that points at it), or shell init (`tool init zsh`).

2. **Pick the release.** The newest non-prerelease that's at least two weeks old:
   ```sh
   gh api "repos/OWNER/REPO/releases?per_page=8" --jq '.[] | select(.prerelease|not) | "\(.tag_name) \(.published_at)"'
   gh api repos/OWNER/REPO/releases/tags/TAG --jq '.assets[] | "\(.name) \(.size) \(.digest)"'
   ```
   Prefer `x86_64-unknown-linux-musl` / `aarch64-unknown-linux-musl` (static). If only a glibc build exists for a target, use it and say so in a comment. Archives can be `.tar.gz` (the default), `.tar.xz`, `.tar.zst`, `.tar` or `.zip`: set `format` to match the URL (`goatty-plugin hash` prints it, and `validate` refuses a mismatch). A raw executable is `format = "binary"`. macOS builds go under `x86_64-macos` / `aarch64-macos`.

3. **Hash and inspect each asset:** `goatty-plugin hash URL…`. The printed sha256 must equal upstream's digest (`sha256:…` from the API above, or the project's checksums file). The listed executables give `bin` and `root` (the directory inside the archive, `""` for the top level).

4. **Design the settings.** Choose the 4–10 options a newcomer benefits from most. For each:
   - `label`: short, plain. `help`: what changes, in everyday words, including any catch ("needs a Nerd Font", "slower in huge repositories").
   - The narrowest type: `bool` > `choice` > `integer` > `string`/`path`/`list`. Give every `choice` option a `label`, and `help` where the value isn't obvious.
   - A good default: the experience a goatty user should get out of the box, never surprising for someone who knows the tool.
   - `group` related settings; mark rarely needed ones `advanced = true`.
   - Replacing a common command (`ls`, `cat`, `cd`) always gets its own `bool` setting.

5. **Wire them up**, in this order of preference:
   - flags → each setting's `arg` (`--icons={value}`, bool `arg`/`arg_off`, per-choice `arg`, `""` for none) and an `[[alias]]` with `args = ["{args}"]`;
   - one-off tasks people would otherwise look up ("open a shell in a container", "find files by name") → a `[[command]]` for the palette with `[[command.input]]`s (typed: text/integer/number/path/folder/choice, with placeholder, `pattern`, `min`/`max`); its `run` words are quoted by goatty, never build shell code from inputs; an input people pick from a list (a container, a branch) gets a `[command.input.source]` (argv of the plugin's own program, no shell; adds `snippet-sources`, which needs a reason) and `strict = true`;
   - commands people want to read before they run ("switch to a branch", "extract an archive") → a `[[snippet]]` for the snippet picker: a `line` with `{input}` blanks (never inside quotes; goatty quotes every value), a `safety` badge, and suggestions from a `[snippet.input.source]` (argv of the plugin's own program, no shell; adds `snippet-sources`, which needs a reason); plain-words shortcuts typed at the prompt → an `[[expansion]]` (`say` → `to`);
   - environment variables → `[[env]]` with `value = "{setting}"` and `when` conditions;
   - a config file → `[[file]]` (`format = "lines"` with `lines = ["{args}"]`, or `"text"` with a `template`) and `env = "TOOL_CONFIG_VAR"`;
   - only if the tool needs it, `[zsh] init = "zsh/init.zsh"`: read settings from `${goatty_settings[id]}` while it runs (they're unset afterwards; capture what functions need). Keep it to the tool's own init (`eval "$(tool init zsh …)"`) or small function definitions. No network, no downloads, no output, no writes outside `${XDG_CACHE_HOME:-$HOME/.cache}/goatty`, nothing slow per prompt. Cache expensive generated code (see the registry's docker plugin).
   - Completions: if the tool generates them (`tool completions zsh`, `--generate-completion zsh`, …), set `completions = ["tool", …]` in its `[[package]]`. Run it with an empty `$HOME` first: it must print a function starting with `#compdef` and write no files. Otherwise ship `_tool` files with `zsh.fpath = ["zsh/completions"]`.
   - the tool is a zsh plugin (zsh-autosuggestions, zsh-you-should-use, zsh-history-substring-search: a script to source, no program): a `[[package]]` with `source = "name.plugin.zsh"` (relative to the asset root; `bin` may stay empty) and a `[[package.asset]]` (usually `target = "any"` on the upstream source tarball, `root` = its top directory). `system_paths = [...]` lists where distributions install it, so goatty sources that copy and downloads nothing: only absolute paths under `/usr/`, `/opt/homebrew/`, `/opt/local/`, `/run/current-system/sw/` and `/nix/var/nix/profiles/`; look up the real paths for Arch, Debian/Ubuntu/Fedora, Homebrew and NixOS instead of guessing. Needs `binaries` in `[permissions]`. Settings reach the script through `zsh.init`, which runs *before* the script is sourced (`typeset -g ZSH_AUTOSUGGEST_STRATEGY=…`);
   - where it loads: `[zsh] load` = `line-editor` (after compinit, before the prompt: widgets and key bindings, so fzf, autosuggestions, history-substring-search), `prompt`, `normal` (default) or `last` (after the user's own additions: it must wrap every widget defined before it, so syntax highlighting). Within a slot, `after = ["plugin-id"]` loads it after those plugins (when installed and on; a plugin in an earlier slot always counts as loaded). Read the tool's README for what it must load before or after, and don't guess the slot. Older goatty builds refuse these fields: set `[compat] goatty`. The commented example at the end of this repository's `plugin.toml` shows all of it; goatty's `docs/plugins.md` ("Load order") is the reference.
   Templates: `{id}` value, `{id.arg}`/`{args}` arguments, `{value}` in a setting's own `arg`, `{{`/`}}` literal braces. Conditions: `id`, `!id`, `id=value`, `id!=value`.

6. **Permissions.** `[permissions]` needs a one-sentence reason for `binaries` (any `[[package]]`, zsh-plugin packages too), `shell-code` (any `zsh.init`) and `network` (declare it if the tool itself uses the network). Don't declare what the manifest doesn't use.

7. **Check everything:**
   ```sh
   goatty-plugin validate .
   goatty-plugin render . --set id=value   # read the generated aliases, env, files
   goatty-plugin check-downloads .
   zsh -n zsh/*.zsh
   ```
   Optionally try it: `goattyd plugin install --path .` (on a test machine or with a throwaway `HOME`).

8. **Versions.** `version` is the plugin's own semver: bump it for any change (a new tool version is at least a minor bump). In the registry, a new version is a new `plugins/<id>/<version>/` directory; never edit a published one.

## Hard rules

- Downloads: official releases of the tool's own project, `https://` only, sha256 verified against upstream, release ≥ 2 weeks old.
- Never: `curl | sh`, sudo, editing dotfiles or anything outside goatty's directories, setting `PATH`/`LD_*`/`GOATTY_*` variables (validation refuses them).
- Don't guess flags: confirm every flag and variable in the tool's docs for that exact version.
- Plain words in every user-visible string; no marketing.
