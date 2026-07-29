# OBS Cursor Tools

[![AutoHotkey](https://img.shields.io/badge/Language-AutoHotkey_v2-green.svg)](https://www.autohotkey.com/)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue.svg)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-GPL_v3-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.0-brightgreen.svg)](https://github.com/mesutakcan/OBS-Cursor-Tools/releases) 

![GitHub stars](https://img.shields.io/github/stars/mesutakcan/OBS-Cursor-Tools?style=social)
![GitHub forks](https://img.shields.io/github/forks/mesutakcan/OBS-Cursor-Tools?style=social)
![GitHub issues](https://img.shields.io/github/issues/mesutakcan/OBS-Cursor-Tools)
[![Downloads](https://img.shields.io/github/downloads/mesutakcan/OBS-Cursor-Tools/total)](https://github.com/mesutakcan/OBS-Cursor-Tools/releases)


Make your mouse easy to follow in OBS Studio recordings.

OBS Cursor Tools highlights your cursor, shows which mouse button was clicked, and adds a visible click animation. It is useful for tutorials, software demonstrations, presentations, and any screen recording where viewers need to see your mouse clearly.

## What it does

- Shows a highlighter ring around the cursor.
- Uses different colors for left, middle, and right clicks.
- Shows a ripple animation when you click.
- Syncs recording controls with OBS Studio.
- Displays a short notification when recording starts, stops, or pauses.
- Remembers mouse positions so you can return to them quickly.
- Types clipboard text while keeping its indentation.
- Lets you change colors, sizes, transparency, and hotkeys.

## Download and install

1. Download the latest version from [Releases](https://github.com/mesutakcan/OBS-Cursor-Tools/releases).
2. Extract the downloaded ZIP file to a folder.
3. Start <code>OBS-Cursor-Tools.exe</code>.
4. The application will continue running in the notification area near the clock.

You can also run <code>OBS-Cursor-Tools.ahk</code> directly if [AutoHotkey v2](https://www.autohotkey.com/) is installed.

> Keep <code>OBS-Cursor-Tools.exe</code>, <code>settings.ini</code>, <code>app_icon.ico</code>, and the <code>lib</code> folder together when using the portable release.

## Quick start

1. Start OBS Studio and OBS Cursor Tools.
2. Turn the highlighter on with <kbd>Ctrl+Shift+F8</kbd>.
3. Start or stop recording from OBS, or use the synced recording hotkey.
4. Move and click normally. The cursor ring and click animations will appear in the recording.
5. Turn the highlighter off with the same hotkey when you no longer need it.

The application runs in the background. Right-click its notification-area icon to open the menu.

## Default hotkeys

| Action | Default hotkey |
|---|---|
| Turn highlighter on/off | <kbd>Ctrl+Shift+F8</kbd> |
| Save mouse position | <kbd>Ctrl+Numpad6</kbd> |
| Move to saved position | <kbd>Ctrl+Numpad4</kbd> |
| Move to previous position | <kbd>Ctrl+Numpad7</kbd> |
| Start/stop recording | Automatically read from OBS |
| Pause/resume recording | Automatically read from OBS |
| Type from clipboard | <kbd>Ctrl+.</kbd> |

The actual hotkeys currently in use are shown in the tray menu under **Hotkeys**.

## OBS Studio setup

OBS Cursor Tools reads the recording hotkeys from your active OBS profile.

For reliable synchronization:

- OBS **Start Recording** and **Stop Recording** must use the same hotkey.
- OBS **Pause Recording** and **Unpause Recording** must use the same hotkey.
- OBS should be running before OBS Cursor Tools starts.

If OBS is not installed, is not running, or its profile cannot be found, the application continues using the values in <code>settings.ini</code>.

If OBS reports a hotkey mismatch, open **OBS → Settings → Hotkeys**, correct the assignments, and restart OBS Cursor Tools.

## Notification-area menu

Right-click the application icon to access:

- **Toggle Highlighter** — Turn cursor highlighting on or off.
- **Save mouse position** — Remember the current cursor position.
- **Move mouse to saved position** — Return to the remembered position.
- **Move mouse to previous position** — Move backward through saved positions.
- **Start/stop recording** — Use the OBS recording hotkey.
- **Pause/resume recording** — Use the OBS pause hotkey.
- **Type from clipboard** — Type copied text while preserving indentation.
- **Hotkeys** — View the current hotkey assignments.
- **About** — View version and project information.
- **Restart script** — Restart the application.
- **Exit** — Close the application.

## Change the appearance and hotkeys

The application uses the <code>settings.ini</code> file in the same folder.

1. Exit OBS Cursor Tools.
2. Open <code>settings.ini</code> in a text editor.
3. Change the values you want.
4. Save the file.
5. Start OBS Cursor Tools again.

You can change:

- Ring and click colors.
- Ring size and thickness.
- Transparency.
- Click-animation size and speed.
- Mouse and recording hotkeys.

The color values use ARGB hexadecimal format, for example <code>0xFFFF0000</code> for an opaque red color. If you are unsure about a setting, keep a backup of <code>settings.ini</code> before editing it.

## Settings Reference

All settings live in `settings.ini`, organized into three sections. Edit values with a text editor while the application is closed, then start it again.

### [Hotkeys]

Hotkeys use AutoHotkey v2 format: `^` = Ctrl, `!` = Alt, `+` = Shift, `#` = Win. Example: `^+F8` means Ctrl+Shift+F8.

| Key | Meaning | Default |
|---|---|---|
| `toggleHighlight` | Turns the cursor highlighter on/off | `^+F8` |
| `moveMousePos` | Moves the cursor to the saved position | `^Numpad4` |
| `movePrevMousePos` | Moves the cursor to the previous position | `^Numpad7` |
| `saveMousePos` | Saves the current cursor position | `^Numpad6` |
| `handlePause` | Pauses/resumes recording | `Pause` (auto-synced with OBS) |
| `handleRecording` | Starts/stops recording | `^Numpad0` (auto-synced with OBS) |
| `typeFromClipboard` | Types out the clipboard text | `^.` |

### [Conf]

Controls the size, timing, and transparency of the ring and click animation. All transparency values range from `0` (invisible) to `255` (fully opaque).

| Key | Meaning | Default |
|---|---|---|
| `diameter` | Outer diameter of the highlighter ring, in pixels | `48` |
| `thickness` | Thickness of the ring border, in pixels | `4` |
| `ringTransparency` | Transparency of the ring border | `190` |
| `circleTransparency` | Transparency of the inner fill | `170` |
| `animTransparency` | Transparency of the click animation at the start | `255` |
| `endTransparency` | Transparency of the click animation at the end | `0` |
| `steps` | Number of frames in the click animation | `15` |
| `startDiameter` | Click animation diameter at the start, in pixels | `10` |
| `endDiameter` | Click animation diameter at the end, in pixels | `50` |
| `animTargetFrameTime` | Target time per animation frame, in milliseconds | `16.67` |
| `padding` | Gap between the ring and the inner fill, in pixels | `3` |

### [Colors]

Colors use ARGB hexadecimal format: `0xAARRGGBB`, where `AA` is opacity (`00`–`FF`) and `RR`/`GG`/`BB` are the red, green, and blue components.

| Key | Meaning | Default |
|---|---|---|
| `defaultBack` | Fill color when no button is pressed | `0x00FFFFFF` (transparent) |
| `defaultBorder` | Ring color when no button is pressed | `0xFF00FFFF` (cyan) |
| `leftBack` | Fill color on left click | `0xFFFF0000` (red) |
| `leftBorder` | Ring color on left click | `0xFF00FFFF` (cyan) |
| `middleBack` | Fill color on middle click | `0xFF00FFFF` (cyan) |
| `middleBorder` | Ring color on middle click | `0xFFFF00FF` (magenta) |
| `rightBack` | Fill color on right click | `0xFF00FF00` (green) |
| `rightBorder` | Ring color on right click | `0xFFFF0000` (red) |

## Troubleshooting

### The highlighter does not appear

Make sure the application is running and press the highlighter hotkey. Check the current assignment from the tray menu under **Hotkeys**.

### Recording controls do not work

Confirm that OBS is running and that its Start/Stop or Pause/Unpause actions use matching hotkeys. Then restart OBS Cursor Tools.

### My hotkeys are different

The values in <code>settings.ini</code> may have been updated from OBS. Check the current assignments through the **Hotkeys** menu.

### The application does not start

If you are running the <code>.ahk</code> file, install AutoHotkey v2. If you are using the executable, extract the complete release package instead of copying only the <code>.exe</code> file.

## Requirements

- Windows 10 or later.
- [OBS Studio](https://obsproject.com) is recommended for automatic recording-hotkey synchronization.
- [AutoHotkey v2](https://www.autohotkey.com/) is required only when running the <code>.ahk</code> file directly.

## Known Issues

- **Cursor ring may briefly lag during very fast dragging on low-end systems.** The highlighter is decoupled from the mouse hook to avoid freezing, but under heavy CPU load (e.g. software encoding in OBS) extremely fast movements may still show a very short visual delay.
- **OBS hotkey sync requires matching keys.** If Start Recording / Stop Recording (or Pause / Unpause) use different hotkeys in OBS, automatic synchronization will not work correctly. Assign the same hotkey to both actions in OBS Settings → Hotkeys.
- **Non-standard OBS installations may not be detected.** Hotkeys are read from the active OBS profile's configuration files in the default OBS config location. Portable OBS installations or custom config paths are not automatically detected.
- **Numpad-based hotkeys require a physical numpad.** On laptops without a dedicated numpad, these hotkeys may need Fn/NumLock emulation, or can be reassigned in `settings.ini`.

## Credits

This application uses the library file [Gdip_All.ahk](https://github.com/buliasz/AHKv2-Gdip/blob/master/Gdip_All.ahk) from the [AHKv2-Gdip](https://github.com/buliasz/AHKv2-Gdip) project for GDI+ rendering.

## History
### v1.0 2026-07-29
- Initial release


## License

See the [LICENSE](LICENSE) file for license details.

## Contributing

Contributions are welcome! If you'd like to add features, fix bugs, or improve the code, feel free to open a pull request.

## Contact

**Author**: Mesut Akcan\
**Email**: <makcan@gmail.com>\
**Blog**: [mesutakcan.blogspot.com](http://mesutakcan.blogspot.com)\
**GitHub**: [mesutakcan](http://github.com/mesutakcan)\
**YouTube**: [Mesut Akcan](http://youtube.com/mesutakcan)