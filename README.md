# Mac Timezones

A simple macOS toolbar app that monitors your clipboard for time data and converts it to your local timezone.

## Features

- Lives in your macOS menu bar
- Automatically detects time data in your clipboard
- Converts times to your local timezone
- Handles various time formats
- Assumes UTC if no timezone is specified

## Usage

1. Copy text containing a time (e.g., "Meeting at 9PM EST tomorrow")
2. The app will automatically detect the time and show the conversion in your local timezone
3. Click on the menu bar icon to see the last detected time conversion

## Building

This project is written in Swift and requires Xcode to build.

1. Open the project in Xcode
2. Build and run the project (⌘+R)
3. The app will appear in your menu bar

## Requirements

- macOS 11.0 or later 