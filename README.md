# Pic Thing Background Removal for macOS

## Overview

Pic Thing Background Removal is a macOS extension that allows you to quickly remove backgrounds from your images directly from Finder. Simply select an image, use the Quick Actions menu, and get a transparent PNG with the background removed.

**DISCLAIMER: This application is not affiliated with, endorsed by, or connected to ping.gg. This is an unofficial tool that uses Pic Thing's services.**

## Features

- Remove backgrounds from images with a single click
- Works directly from Finder as a Quick Action
- Supports various image formats (JPG, PNG, HEIC)
- Returns transparent PNG files with "_nobg" suffix

## Requirements

- macOS 10.15 (Catalina) or newer
- An active Pic Thing account
- Your session token and session ID from Pic Thing

## Installation

1. Download the latest release from the Releases page
2. Open the DMG file and drag the app to your Applications folder
3. Open the app once to configure it
4. Enter your session token and session ID when prompted
5. Enable the Quick Action in System Preferences:
   - Go to System Preferences > Extensions
   - Select "Finder" in the sidebar
   - Check "Remove Background with Pic Thing"

## How to Use

1. In Finder, select one or more image files
2. Right-click and choose "Quick Actions" > "PicThing"
3. Wait for processing to complete
4. The processed images will appear in the same folder with "_nobg" added to the filename

## How to Get Your Session Token and Session ID

To use this app, you need to get your session token and session ID from Pic Thing:

1. Go to [pic.ping.gg](https://pic.ping.gg) and log in
2. Open your browser's Developer Tools (right-click > Inspect or press F12)
3. Go to the "Application" tab
4. In the sidebar, under "Storage", select "Cookies" > "https://pic.ping.gg"
5. Find the cookie named "__client" - the value is your client token
6. Find the cookie that starts with "clerk_active_context=sess_" - the "sess_" part followed by the string of characters is your session ID

Enter these values in the app's settings to authenticate your requests.

## Privacy & Security

- Your session credentials are stored securely on device
- No data is sent to any servers other than Pic Thing's official servers
- All processing happens through the official Pic Thing API

## Troubleshooting

If you encounter issues:

- Ensure your session token and session ID are current
- Check your internet connection
- Make sure the images are in supported formats
- Look for error logs created by the app in the same folder as processed images

If the app creates a text file instead of a processed image, open it to see what went wrong.

## Legal

This application is provided "as is" without warranty of any kind. It is not affiliated with ping.gg or Pic Thing's official services. Use at your own risk.

The app leverages Pic Thing's public API as an end-user. If you are a representative of ping.gg and have concerns about this application, please contact me Thomas Dye.

## Credits

Developed by Thomas
Based on the background removal technology provided by Pic Thing
