# EVE Signature Tracker

A PowerShell-based signature tracking tool for EVE Online that helps you manage and share cosmic signatures discovered during exploration.

![EVE Signature Tracker in Action](assets/eve-sig-tracker-screenshot.png)

## What is this?

This tool helps EVE Online explorers track cosmic signatures (wormholes, data sites, relic sites, etc.) by:
- Automatically detecting signatures from EVE's clipboard
- Storing signature data locally with timestamps
- Allowing manual registration of signatures
- Supporting data sharing between players
- Showing signature age to help with cleanup

## Features

- **Automatic Detection**: Automatically reads EVE signature data from your clipboard
- **Local Storage**: Keeps track of signatures in a CSV file
- **Age Tracking**: Shows how old signatures are (e.g., "1dh13" = 1 day 13 hours)
- **Data Sharing**: Export/import signature data between players
- **Manual Registration**: Add signatures manually with group selection
- **Duplicate Handling**: Smart merging when importing shared data
- **UTC Timestamps**: No timezone issues when sharing between players
- **Automatic Cleanup**: Removes signatures older than 3 days automatically

## How to Use

### Basic Usage

1. **Run the script**: `powershell -ExecutionPolicy Bypass -File evesigs.ps1`
2. **Copy EVE data**: Copy signature data from EVE's signature scanner
3. **Press any key**: The script automatically reads your clipboard and processes the data
4. **View results**: See which signatures are new, updated, or already known

### Menu Options

- **[A] Show All**: Display all stored signatures
- **[R] Register**: Manually add a signature (ID + group selection)
- **[D] Delete**: Remove signatures by ID
- **[X] Export**: Export all signatures to clipboard for sharing
- **[I] Import**: Import shared signature data from other players

### Manual Registration

1. Press `R` for manual registration
2. Enter signature ID (e.g., "NEH-246")
3. Select group type:
   - `1` - Combat Site
   - `2` - Data Site
   - `3` - Gas Site
   - `4` - Relic Site
   - `5` - Wormhole

### Data Sharing

**Exporting:**
1. Press `X` to export all signatures
2. Data is copied to clipboard as a single line
3. Share this line with other players

**Importing:**
1. Press `I` to import shared data
2. Paste the shared data line
3. Script automatically merges data, favoring oldest timestamps

## EVE Data Format

The tool expects EVE's standard clipboard format:
```
HJA-862	Cosmic Signature	Wormhole	Unstable Wormhole	100,0%	4,76 AU
KOC-906	Cosmic Signature	Data Site	Limited Sleeper Cache	0,0%	3,40 AU
```

## File Structure

- `evesigs.ps1` - Main script
- `evesigs.csv` - Local signature database (created automatically)
- `EVE Sig Analyzer.lnk` - Windows shortcut

## Requirements

- Windows PowerShell

## Credits

Made by: Nehalennia  
Started: 2020-26-10

---

*This tool is designed for EVE Online exploration and signature scanning. It helps track cosmic signatures across wormhole space and other exploration areas.* 
