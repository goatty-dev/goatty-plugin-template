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
   Prefer `x86_64-unknown-linux-musl` / `aarch64-unknown-linux-musl` (static). If only a glibc build exists for a target, use it and say so in a comment. Only `.tar.gz` archives or raw binaries (`format = "binary"`) are supported.

3. **Hash and inspect each asset:** `goatty-plugin hash URL…`. The printed sha256 must equal upstream's digest (`sha256:…` from the API above, or the project's checksums file). The listed executables give `bin` and `root` (the directory inside the archive, `""` for the top level).

4. **Design the settings.** Choose the 4–10 options a newcomer benefits from most. For each:
   - `label`: short, plain. `help`: what changes, in everyday words, including any catch ("needs a Nerd Font", "slower in huge repositories").
   - The narrowest type: `bool` > `choice` > `integer` > `string`/`path`/`list`. Give every `choice` option a `label`, and `help` where the value isn't obvious.
   - A good default: the experience a goatty user should get out of the box, never surprising for someone who knows the tool.
   - `group` related settings; mark rarely needed ones `advanced = true`.
   - Replacing a common command (`ls`, `cat`, `cd`) always gets its own `bool` setting.

5. **Wire them up**, in this order of preference:
   - flags → each setting's `arg` (`--icons={value}`, bool `arg`/`arg_off`, per-choice `arg`, `""` for none) and an `[[alias]]` with `args = ["{args}"]`;
   - environment variables → `[[env]]` with `value = "{setting}"` and `when` conditions;
   - a config file → `[[file]]` (`format = "lines"` with `lines = ["{args}"]`, or `"text"` with a `template`) and `env = "TOOL_CONFIG_VAR"`;
   - only if the tool needs it, `[zsh] init = "zsh/init.zsh"`: read settings from `${goatty_settings[id]}` while it runs (they're unset afterwards; capture what functions need). Keep it to the tool's own init (`eval "$(tool init zsh …)"`) or small function definitions. No network, no downloads, no output, no writes outside `${XDG_CACHE_HOME:-$HOME/.cache}/goatty`, nothing slow per prompt. Cache expensive generated code (see the registry's docker plugin).
   - Completions: `zsh.fpath = ["zsh/completions"]` with `_tool` files shipped in the plugin.
   Templates: `{id}` value, `{id.arg}`/`{args}` arguments, `{value}` in a setting's own `arg`, `{{`/`}}` literal braces. Conditions: `id`, `!id`, `id=value`, `id!=value`.

6. **Permissions.** `[permissions]` needs a one-sentence reason for `binaries` (any `[[package]]`), `shell-code` (any `zsh.init`) and `network` (declare it if the tool itself uses the network). Don't declare what the manifest doesn't use.

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
