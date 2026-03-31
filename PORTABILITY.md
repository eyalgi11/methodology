# Portability Guide

Use this guide when you want to run the methodology from a fresh clone on another Linux or WSL machine.

## Goal

The toolkit should work without hardcoding one workstation's:
- home directory
- username
- clone path
- shell startup file layout

Portable use depends on two surfaces:
- `METHODOLOGY_HOME` for the installed toolkit location
- `methodology/toolkit-path.txt` inside each bootstrapped project

## Install From A Fresh Clone

From the cloned methodology repo root:

```bash
./install-toolkit.sh
```

That will:
- write `METHODOLOGY_HOME` to `~/.config/methodology/config.env`
- install a small `mtool` wrapper into `~/.local/bin`
- optionally add shared methodology shell snippets to `~/.bashrc` and `~/.zshrc`

That shell setup enables portable helpers in both bash and zsh:
- `mstart`
- `mresume`
- `mupdate`
- `madopt`

After that, these are equivalent:

```bash
./methodology-entry.sh /path/to/project
mtool methodology-entry.sh /path/to/project
```

Use `./script.sh` when you are already in the methodology repo root.
Use `mtool script.sh` when you are somewhere else on the machine.

After reloading your shell rc files, the shared shell helpers should work in either shell:

```bash
mstart
mresume
mupdate
madopt
```

## Project Bootstrap Behavior

Bootstrapped projects now record the toolkit location in:

```text
methodology/toolkit-path.txt
```

That gives each project a stable hint for:
- next-step commands
- generated instructions
- cloned-toolkit reuse on the current machine

Generated project files should resolve the toolkit through:
1. `METHODOLOGY_HOME` when it exists
2. `methodology/toolkit-path.txt` otherwise

## Linux And WSL Expectations

Supported target environments:
- Linux
- WSL

Portable baseline assumptions:
- `bash` is available
- standard Unix utilities exist
- Git is installed

Environment-specific notes:
- Browser automation may still depend on a locally installed browser and extension setup.
- Mobile automation may still depend on Android SDK, emulator, or device setup.
- Localhost certificate trust can vary across machines; the Playwriter/local-page bridge already supports HTTP fallback for local-file browsing when HTTPS trust is not ready.

## What The Portability Check Guards

Run this from the methodology repo root:

```bash
./portability-check.sh .
```

It flags machine-specific runtime assumptions in shell scripts, especially:
- hardcoded home directories
- hardcoded usernames
- local-only runtime paths that should resolve through `METHODOLOGY_HOME` or project-local hints instead

This is the quickest guard against drifting back into workstation-specific tooling.

## What CI Should Prove

The toolkit is GitHub-ready when CI can prove:
- the registry is complete
- portability checks pass
- methodology CI checks pass
- a fresh install works
- a fresh bootstrap writes `methodology/toolkit-path.txt`

The GitHub workflow in `.github/workflows/methodology-ci.yml` is the default proof surface for that.

## What Is Still Local By Nature

Some workflows are intentionally local-machine dependent and should stay that way:
- Brave / Playwriter profile state
- installed browser extensions
- Android emulator or physical device state
- machine-local dev databases and background services

The portability goal is not to make those identical everywhere.
The goal is to make the toolkit itself relocatable, installable, and predictable across machines.
