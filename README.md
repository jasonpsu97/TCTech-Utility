# Twisted Computing Tech Utility

A customized Windows technician utility for Twisted Computing, based on the open-source Chris Titus Tech WinUtil project.

## Run from anywhere

After the contents of this folder are pushed to the `main` branch of `jasonpsu97/TCTech-Utility`, open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/jasonpsu97/TCTech-Utility/main/launch.ps1 | iex
```

The bootstrap launcher downloads the current `main` branch to:

```text
%LOCALAPPDATA%\TwistedComputing\TCTech-Utility
```

It then starts the utility through the existing elevated launcher.

## Run locally

Extract the full project and double-click:

```text
Launch-Twisted-Computing-Tech-Utility.cmd
```

Do not run individual files from inside the ZIP.

## Current release

Version `1.2.0` is the first GitHub-ready baseline. It preserves the working v1.1 application and adds only the online bootstrap, version file, and project documentation.

## Project layout

- `launch.ps1` — permanent GitHub one-line bootstrap
- `Launch-TCTech-Utility.ps1` — local elevated launcher and splash
- `Launch-Twisted-Computing-Tech-Utility.cmd` — local double-click launcher
- `winutil.ps1` — compiled application
- `assets/` — Twisted Computing artwork
- `config/`, `functions/`, `xaml/` — application source and configuration
- `VERSION` — current TC Utility version

## Upstream and licensing

This project is derived from Chris Titus Tech WinUtil. The original license and attribution remain included in this repository. Twisted Computing customizations are maintained separately from upstream where practical.
