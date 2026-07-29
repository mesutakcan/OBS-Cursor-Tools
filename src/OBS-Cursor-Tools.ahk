/*
OBS Cursor Tools is a lightweight AutoHotkey application that enhances OBS Studio recordings with cursor highlighting,
click animations, and recording shortcuts.
---------------------
v1.0.0 - 2026-07-29
Mesut Akcan
github.com/mesutakcan
*/

;@Ahk2Exe-SetDescription OBS Cursor Tools
;@Ahk2Exe-SetFileVersion 1.0.0
;@Ahk2Exe-SetCopyright ©2026 Mesut Akcan
;@Ahk2Exe-SetMainIcon app_icon.ico

#Requires AutoHotkey v2
#SingleInstance Force

#Include "lib/gdip_all.ahk"
#Include "lib/graphics-gdi.ahk"
#Include "lib/paste.ahk"
#Include "lib/mouse.ahk"
#Include "lib/anim.ahk"

SendMode("Event")
CoordMode("Mouse", "Screen"), CoordMode("Pixel", "Screen"), CoordMode("ToolTip", "Screen")
SetKeyDelay(30)
ProcessSetPriority("AboveNormal")

try TraySetIcon("app_icon.ico")

global app := {
	ver: "1.0.0",
	name: "OBS Cursor Tools",
	author: "Mesut Akcan",
	github: "https://github.com/mesutakcan/OBS-Cursor-Tools",
	iniFile: A_ScriptDir "\settings.ini",
	rings: Map(),
	circles: Map(),
	animCircles: Map(),
	msgGui: "",
	msgText: ""
}

A_TrayMenu.Delete()
LoadSettings()
SyncOBSHotkeys()

global mnuHl := "Toggle Highlighter`t" HotkeyToText(HK.toggleHighlight)
global DllCall_CallNextHookEx := DllCall.Bind("CallNextHookEx", "Ptr", 0, "Int", , "UInt", , "Ptr", , "Ptr")

global State := {
	recording: false,
	paused: false,
	hl: false,
	toggle_used: false,
	Hook: "",
	lastUpdate: 0,
	mousePosHistory: [],
	mousePosLength: 5,
	prevPosIndex: 0
}

IniReadInt(section, key, defaultValue) {
	return Integer(IniRead(app.iniFile, section, key, defaultValue))
}

IniReadFloat(section, key, defaultValue) {
	return Float(IniRead(app.iniFile, section, key, defaultValue))
}

CreateTrayMenu()

RegisterHotkeys()

StartGDIPlus()
InitGraphics()
MouseGetPos(&x, &y)

HandlePause() {
	if !State.recording
		return
	State.paused := !State.paused
	if State.paused {
		saveMousePos()
		showHighlight(false)
		ShowMessage("⏸ Recording paused!", "ffee00", "009e00", 175, 1000)
	} else {
		moveMousePos()
		if State.hl {
			showHighlight(true)
			ShowMessage("▶ Recording resumed!", "ffee00", "ff0000", 175, 1000)
		}
	}
}

HandleRecording() {
	static processing := false
	if processing
		return

	NotifyKeyboardOSD_Hide()
	processing := true

	State.recording := !State.recording
	if State.recording {
		if !State.toggle_used {
			State.hl := true
		}
		State.paused := false
		ShowMessage("▶ Recording started!", "ff0000", "ffffff", 175, 1000)
		moveMousePos()
		if State.hl {
			showHighlight(true)
		}
	} else {
		saveMousePos()
		showHighlight(false)
		ShowMessage("⏹ Recording stopped!", "008f00", "ffffff", 175, 2000)
	}

	processing := false
}

NotifyKeyboardOSD_Hide() {
	DetectHiddenWindows(true)
	Try PostMessage(0x5555, 0, 0, , "Keyboard OSD ahk_class AutoHotkeyGUI")
	DetectHiddenWindows(false)
}

ShowMessage(msg, bgcolor := "008f00", fgcolor := "ffffff", transparency := 175, duration := 2000) {
	if !IsObject(app.msgGui) {
		app.msgGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
		app.msgGui.MarginX := 18
		app.msgGui.MarginY := 14
		app.msgGui.SetFont("s14 w700", "Segoe UI")
		app.msgText := app.msgGui.Add("Text", "Center w220", msg)
		try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", app.msgGui.hwnd, "int", 33, "int*", 2, "int", 4)
	}
	app.msgGui.BackColor := bgcolor
	app.msgText.Opt("c" fgcolor)
	app.msgText.Text := msg
	app.msgGui.Show("NoActivate AutoSize")
	WinSetTransparent(transparency, app.msgGui)
	SetTimer(HideMessage, 0)
	SetTimer(HideMessage, -duration)
}

HideMessage() {
	if IsObject(app.msgGui)
		app.msgGui.Hide()
}

UpdateTrayMenu() {
	if State.hl
		A_TrayMenu.Check(mnuHl)
	else
		A_TrayMenu.UnCheck(mnuHl)
}

HotkeyToText(hk) {
	label := StrReplace(hk, "+", "Shift+")
	label := StrReplace(label, "^", "Ctrl+")
	label := StrReplace(label, "!", "Alt+")
	label := StrReplace(label, "#", "Win+")
	return label
}

ShowHotkeys() {
	text := "Assigned Hotkeys:`n`n"
	text .= "Toggle Highlighter:`t" HotkeyToText(HK.toggleHighlight) "`n"
	text .= "Save Mouse Position:`t" HotkeyToText(HK.saveMousePos) "`n"
	text .= "Move to Saved Pos:`t" HotkeyToText(HK.moveMousePos) "`n"
	text .= "Move to Previous Pos:`t" HotkeyToText(HK.movePrevMousePos) "`n"
	text .= "Start/Stop Recording:`t" HotkeyToText(HK.handleRecording) "`n"
	text .= "Pause/Resume Recording:`t" HotkeyToText(HK.handlePause) "`n"
	text .= "Type from Clipboard:`t" HotkeyToText(HK.typeFromClipboard)
	MsgBox(text, "Hotkeys", "Iconi")
}

RegisterHotkeys() {
	global HK
	RegisterHotkeyWithNumpadAlt(HK.toggleHighlight, (*) => ToggleHighlight())
	RegisterHotkeyWithNumpadAlt(HK.moveMousePos, (*) => moveMousePos())
	RegisterHotkeyWithNumpadAlt(HK.movePrevMousePos, (*) => movePrevMousePos())
	RegisterHotkeyWithNumpadAlt(HK.saveMousePos, (*) => saveMousePos())
	RegisterHotkeyWithNumpadAlt("~" HK.handlePause, (*) => HandlePause())
	RegisterHotkeyWithNumpadAlt("~" HK.handleRecording, (*) => HandleRecording())
	RegisterHotkeyWithNumpadAlt(HK.typeFromClipboard, (*) => typeFromClipboard())
}

RegisterHotkeyWithNumpadAlt(hk, callback) {
	Hotkey(hk, callback)
	static numpadAlts := Map(
		"Numpad0", "NumpadIns",
		"Numpad1", "NumpadEnd",
		"Numpad2", "NumpadDown",
		"Numpad3", "NumpadPgDn",
		"Numpad4", "NumpadLeft",
		"Numpad5", "NumpadClear",
		"Numpad6", "NumpadRight",
		"Numpad7", "NumpadHome",
		"Numpad8", "NumpadUp",
		"Numpad9", "NumpadPgUp",
		"NumpadDot", "NumpadDel"
	)
	for numKey, altKey in numpadAlts {
		if InStr(hk, numKey) {
			altHk := StrReplace(hk, numKey, altKey)
			try Hotkey(altHk, callback)
		}
	}
}

LoadSettings() {
	global colors, Conf, HK

	HK := {
		toggleHighlight: IniRead(app.iniFile, "Hotkeys", "toggleHighlight", "^+F8"),
		moveMousePos: IniRead(app.iniFile, "Hotkeys", "moveMousePos", "^Numpad4"),
		movePrevMousePos: IniRead(app.iniFile, "Hotkeys", "movePrevMousePos", "^Numpad7"),
		saveMousePos: IniRead(app.iniFile, "Hotkeys", "saveMousePos", "^Numpad6"),
		handlePause: IniRead(app.iniFile, "Hotkeys", "handlePause", "Pause"),
		handleRecording: IniRead(app.iniFile, "Hotkeys", "handleRecording", "^Numpad0"),
		typeFromClipboard: IniRead(app.iniFile, "Hotkeys", "typeFromClipboard", "^.")
	}

	static DefColors := {
		default: { back: "0x00FFFFFF", border: "0xFF00FFFF" },
		l: { back: "0xFFFF0000", border: "0xFF00FFFF" },
		m: { back: "0xFF00FFFF", border: "0xFFFF00FF" },
		r: { back: "0xFF00FF00", border: "0xFFFF0000" }
	}

	colors := Map(
		"default", {
			back: IniRead(app.iniFile, "Colors", "defaultBack", DefColors.default.back),
			border: IniRead(app.iniFile, "Colors", "defaultBorder", DefColors.default.border)
		},
		"l", {
			back: IniRead(app.iniFile, "Colors", "leftBack", DefColors.l.back),
			border: IniRead(app.iniFile, "Colors", "leftBorder", DefColors.l.border)
		},
		"m", {
			back: IniRead(app.iniFile, "Colors", "middleBack", DefColors.m.back),
			border: IniRead(app.iniFile, "Colors", "middleBorder", DefColors.m.border)
		},
		"r", {
			back: IniRead(app.iniFile, "Colors", "rightBack", DefColors.r.back),
			border: IniRead(app.iniFile, "Colors", "rightBorder", DefColors.r.border)
		}
	)

	Conf := {
		diameter: IniReadInt("Conf", "diameter", 48),
		thickness: IniReadInt("Conf", "thickness", 4),
		ringTransparency: IniReadInt("Conf", "ringTransparency", 190),
		circleTransparency: IniReadInt("Conf", "circleTransparency", 170),
		animTransparency: IniReadInt("Conf", "animTransparency", 255),
		endTransparency: IniReadInt("Conf", "endTransparency", 0),
		steps: IniReadInt("Conf", "steps", 15),
		startDiameter: IniReadInt("Conf", "startDiameter", 10),
		endDiameter: IniReadInt("Conf", "endDiameter", 50),
		animTargetFrameTime: IniReadFloat("Conf", "animTargetFrameTime", 16.67),
		padding: IniReadInt("Conf", "padding", 3)
	}

	Conf.offset := -Conf.diameter // 2 - Conf.padding
	Conf.circleDiameter := Conf.diameter - Conf.thickness
	Conf.circlePositionOffset := (Conf.diameter - Conf.circleDiameter) // 2
	Conf.startTransparency := Conf.animTransparency
}

CreateTrayMenu() {
	A_TrayMenu.Add("About", (*) => ShowAbout())
	A_TrayMenu.Add("Hotkeys", (*) => ShowHotkeys())
	A_TrayMenu.Add()
	A_TrayMenu.Add(mnuHl, (*) => ToggleHighlight())
	A_TrayMenu.Add("Save mouse position`t" HotkeyToText(HK.saveMousePos), (*) => saveMousePos())
	A_TrayMenu.Add("Move mouse to saved position`t" HotkeyToText(HK.moveMousePos), (*) => moveMousePos())
	A_TrayMenu.Add("Move mouse to previous position`t" HotkeyToText(HK.movePrevMousePos), (*) => movePrevMousePos())
	A_TrayMenu.Add()
	A_TrayMenu.Add("Start/stop recording`t" HotkeyToText(HK.handleRecording), (*) => HandleRecording())
	A_TrayMenu.Add("Pause/resume recording`t" HotkeyToText(HK.handlePause), (*) => HandlePause())
	A_TrayMenu.Add()
	A_TrayMenu.Add("Type from clipboard`t" HotkeyToText(HK.typeFromClipboard), (*) => TypeFromClipboard())
	A_TrayMenu.Add()
	A_TrayMenu.Add("Restart", (*) => Reload())
	A_TrayMenu.Add("Exit", (*) => ExitApp())
}

ShowAbout(*) {
	m := app.name " v" app.ver "`n`n"
	m .= app.name " is a high-performance presentation and recording assistant that enhances "
	m .= "your video tutorials with real-time mouse highlighting, visual click animations, "
	m .= "and smart layout automation.`n`n"
	m .= "©2026 Mesut Akcan`n"
	m .= "mesutakcan.blogspot.com`n"
	m .= "youtube.com/mesutakcan`n"
	m .= app.github
	MsgBox(m, "About", "IconI")
}

OnExit(CleanupResources)

SyncOBSHotkeys() {
	global HK
	try {
		obsBase := A_AppData "\obs-studio\basic"
		profileDir := GetActiveOBSProfileDir(obsBase)
		if !profileDir {
			AnnounceActiveHotkeys("OBS profile folder was not found; values from settings.ini will be used.")
			return
		}

		iniPath := obsBase "\profiles\" profileDir "\basic.ini"
		if !FileExist(iniPath) {
			AnnounceActiveHotkeys("OBS profile file was not found (" profileDir " ); values from settings.ini will be used.")
			return
		}

		startCombo := ParseOBSHotkey(IniRead(iniPath, "Hotkeys", "OBSBasic.StartRecording", ""))
		stopCombo := ParseOBSHotkey(IniRead(iniPath, "Hotkeys", "OBSBasic.StopRecording", ""))
		pauseCombo := ParseOBSHotkey(IniRead(iniPath, "Hotkeys", "OBSBasic.PauseRecording", ""))
		unpauseCombo := ParseOBSHotkey(IniRead(iniPath, "Hotkeys", "OBSBasic.UnpauseRecording", ""))

		problems := []

		if (startCombo && stopCombo && startCombo != stopCombo) {
			problems.Push("In OBS, 'Start Recording' (" startCombo ") and`n'Stop Recording' (" stopCombo
				") are assigned to different keys.`nBoth must use the SAME key for this script to work.")
		}
		if (pauseCombo && unpauseCombo && pauseCombo != unpauseCombo) {
			problems.Push("In OBS, 'Pause Recording' (" pauseCombo ") and`n'Unpause Recording' (" unpauseCombo
				") are assigned to different keys.`nBoth must use the SAME key for this script to work.")
		}

		if problems.Length {
			msg := "There is an OBS hotkey mismatch that needs to be fixed:`n`n"
			for p in problems
				msg .= "  - " p "`n"
			msg .= "`nFix it in OBS → Settings → Hotkeys.`nUntil then, the script will continue using the previous values from settings.ini."
			MsgBox(msg, "OBS Hotkey Mismatch", "48")
			AnnounceActiveHotkeys("Previous values from settings.ini are being used because of the OBS mismatch.")
			return
		}

		recCombo := startCombo ? startCombo : stopCombo
		pzCombo := pauseCombo ? pauseCombo : unpauseCombo

		changed := false
		if (recCombo && recCombo != HK.handleRecording) {
			HK.handleRecording := recCombo
			IniWrite(recCombo, app.iniFile, "Hotkeys", "handleRecording")
			changed := true
		}
		if (pzCombo && pzCombo != HK.handlePause) {
			HK.handlePause := pzCombo
			IniWrite(pzCombo, app.iniFile, "Hotkeys", "handlePause")
			changed := true
		}

		AnnounceActiveHotkeys(changed ? "Synchronized with OBS (settings.ini updated)." : "In sync with OBS.")
	} catch as e {
		AnnounceActiveHotkeys("Error while checking OBS hotkeys: " e.Message ". Values from settings.ini will be used.")
	}
}

AnnounceActiveHotkeys(statusLine) {
	msg := "Start/Stop Recording:`t" HotkeyToText(HK.handleRecording) "`n"
	msg .= "Pause/Resume Recording:`t" HotkeyToText(HK.handlePause) "`n`n"
	msg .= statusLine
	MsgBox(msg, app.name, "Iconi")
}

GetActiveOBSProfileDir(obsBase) {
	for iniName in [
		"user.ini",
		"global.ini"
	] {
		iniPath := A_AppData "\obs-studio\" iniName
		if !FileExist(iniPath)
			continue
		dir := IniRead(iniPath, "Basic", "ProfileDir", "")
		if dir && FileExist(obsBase "\profiles\" dir "\basic.ini")
			return dir
	}

	profiles := []
	Loop Files, obsBase "\profiles\*", "D" {
		profiles.Push(A_LoopFileName)
	}
	if profiles.Length = 1
		return profiles[1]

	if profiles.Length > 1 {
		newest := "", newestTime := ""
		for p in profiles {
			f := obsBase "\profiles\" p "\basic.ini"
			if !FileExist(f)
				continue
			t := FileGetTime(f, "M")
			if (newestTime = "" || t > newestTime) {
				newestTime := t
				newest := p
			}
		}
		return newest
	}

	return ""
}

ParseOBSHotkey(raw) {
	if !raw
		return ""
	if !RegExMatch(raw, "OBS_KEY_([A-Za-z0-9_]+)", &m)
		return ""
	keyName := ConvertOBSKeyName(m[1])
	if !keyName
		return ""
	combo := ""
	if RegExMatch(raw, '"control"\s*:\s*true')
		combo .= "^"
	if RegExMatch(raw, '"shift"\s*:\s*true')
		combo .= "+"
	if RegExMatch(raw, '"alt"\s*:\s*true')
		combo .= "!"
	return combo . keyName
}

ConvertOBSKeyName(obsKey) {
	static keyMap := Map(
		"NUM0", "Numpad0", "NUM1", "Numpad1", "NUM2", "Numpad2", "NUM3", "Numpad3", "NUM4", "Numpad4",
		"NUM5", "Numpad5", "NUM6", "Numpad6", "NUM7", "Numpad7", "NUM8", "Numpad8", "NUM9", "Numpad9",
		"F1", "F1", "F2", "F2", "F3", "F3", "F4", "F4", "F5", "F5", "F6", "F6", "F7", "F7", "F8", "F8",
		"F9", "F9", "F10", "F10", "F11", "F11", "F12", "F12",
		"PAUSE", "Pause", "INSERT", "Insert", "DELETE", "Delete", "HOME", "Home", "END", "End",
		"PAGEUP", "PgUp", "PAGEDOWN", "PgDn", "SPACE", "Space", "ESCAPE", "Escape", "TAB", "Tab"
	)
	upper := StrUpper(obsKey)
	if keyMap.Has(upper)
		return keyMap[upper]
	if StrLen(obsKey) = 1
		return obsKey
	return ""
}