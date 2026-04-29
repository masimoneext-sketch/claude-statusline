# Claude Code Status Line

A multi-line dashboard status line for [Claude Code](https://claude.ai/claude-code) CLI.

Cross-platform: works on **Linux**, **macOS**, and **Windows** (PowerShell).

![bash](https://img.shields.io/badge/bash-Linux%20%7C%20macOS-green) ![powershell](https://img.shields.io/badge/powershell-Windows-blue)

## Features

- **Model info** — name and model ID, persisted across `/clear`
- **Context window** — usage bar with color coding (green/yellow/red)
- **Token counter** — input, output, and total tokens
- **Cost tracker** — real-time USD and EUR conversion
- **Rate limits** — 5-hour and 7-day usage with reset countdown
- **State persistence** — model and rate limit data survives `/clear`

## Screenshot

```
🤖 Claude Opus 4 (claude-opus-4-20250514)
📊 Contesto  ██░░░░░░░░░░░░░░░░░░ 8%  / 200.0k
🔤 Token     ↓ 45.2k input  ↑ 3.1k output  Σ 48.3k
💶 Costo     $ 0.1250 USD  →  € 0.1138 EUR
⚡ Rate 5h   ██░░░░░░░░░░░░░ 12%  ⏳ reset 4h 32m
📅 Rate 7d   █░░░░░░░░░░░░░░ 3%  ⏳ reset 6d 12h
```

## Requirements

### Linux / macOS

- `jq` — JSON parser
- `bc` — calculator for token/cost formatting

### Windows

- PowerShell 5.1+ or PowerShell 7+ (no extra dependencies)
- Windows Terminal recommended for emoji and color support

## Installation

### Linux / macOS

1. Copy the script:

```bash
cp statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

2. Add to your Claude Code settings (`~/.claude/settings.json`):

```json
{
  "statusline": {
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

### Windows (PowerShell)

1. Copy the script:

```powershell
Copy-Item statusline-command.ps1 "$env:USERPROFILE\.claude\statusline-command.ps1"
```

2. Add to your Claude Code settings (`%USERPROFILE%\.claude\settings.json`):

```json
{
  "statusline": {
    "command": "powershell -NoProfile -File \"%USERPROFILE%\\.claude\\statusline-command.ps1\""
  }
}
```

3. Restart Claude Code.

## Customization

- **USD_TO_EUR** — change the conversion rate (default: `0.91`)
- **Color thresholds** — edit `pick_color()` / `Pick-Color` to adjust green/yellow/red breakpoints
- **Bar width** — change the width argument in `make_bar()` / `Make-Bar` calls

## License

MIT
