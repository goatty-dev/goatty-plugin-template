# goatty plugin template

Start here to build a plugin for [goatty](https://github.com/goatty-dev/goatty), the batteries-included terminal. This repository is a complete, working plugin for [fd](https://github.com/sharkdp/fd): copy it, then replace fd with your tool.

A goatty plugin is one declarative file, [`plugin.toml`](plugin.toml), plus optional zsh files. It tells goatty:

- **what to download**: release archives pinned by sha256, installed into goatty's own directory (never system-wide, never sudo) and put on `PATH` only in goatty shells;
- **which settings to show**: each option with a label and a plain-words explanation, rendered as toggles, choices, steppers or text fields on goatty's Plugins settings page;
- **how settings reach the tool**: aliases, environment variables, a generated config file, or (only when needed) a small zsh file.

goatty shows users all of this before installing: the downloads with their checksums, the permissions with your explanations, and the full text of any shell code.

## Files

```
plugin.toml                    the manifest (every field explained in comments)
zsh/init.zsh                   optional shell code (here: the `fcd` helper)
.github/workflows/validate.yml CI: validate, render, check downloads, zsh -n
.claude/skills/create-goatty-plugin/SKILL.md   a Claude Code skill that builds a plugin with you
```

## Workflow

```sh
# The authoring tool (one-time):
cargo install --git https://github.com/goatty-dev/goatty --locked goatty-plugin

# 1. Describe your tool in plugin.toml. For each release asset:
goatty-plugin hash https://github.com/OWNER/REPO/releases/download/vX/tool-x86_64-unknown-linux-musl.tar.gz
#    → sha256, size, and the executables inside (for `bin` and `root`).
#    Compare the sha256 with upstream's (GitHub lists a sha256 digest per asset).

# 2. Check it:
goatty-plugin validate .            # every problem, with its location
goatty-plugin render . --set hidden=on   # the zsh code and files goatty generates
goatty-plugin check-downloads .     # every asset downloads and matches

# 3. Try it in goatty (on the machine running goattyd):
goattyd plugin install --path .     # shows the install plan, marked "local, unverified"
goattyd plugin set fd hidden on     # or use Settings → Plugins
goattyd plugin uninstall fd
```

Using Claude Code? Open this repository and ask it to "create a goatty plugin for <tool>": the bundled skill (`.claude/skills/create-goatty-plugin`) knows the format, the rules and the checks.

## Publishing

Plugins reach users through a registry. To get into the official one, open a pull request against [goatty-registry](https://github.com/goatty-dev/goatty-registry) that adds your plugin as `plugins/<id>/<version>/` (this directory's `plugin.toml` and `zsh/`, without `.github`, `.claude` or this README). Its [CONTRIBUTING.md](https://github.com/goatty-dev/goatty-registry/blob/main/CONTRIBUTING.md) has the rules; maintainers review against [REVIEW.md](https://github.com/goatty-dev/goatty-registry/blob/main/REVIEW.md) and sign the index.

## What makes a good plugin

- **Approachable settings.** Pick the 4–10 options that matter. Labels are short; `help` explains the effect for someone who has never used the tool. Prefer `choice` over free text.
- **Good defaults.** A fresh install should feel right without touching anything.
- **Declarative first.** Aliases, environment variables and config files are generated and quoted by goatty. Shell code is for tools that need it (like `zoxide init`), and must be small, quiet and fast.
- **Honest permissions.** Explain in `[permissions]` why the plugin needs to run programs or shell code.
- **Pinned and static.** Official releases, at least two weeks old, musl builds on Linux when available.

## License

This template is MIT OR Apache-2.0. Your plugin can use any license; the tool it installs keeps its own.
