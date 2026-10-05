/*
OBS Cursor Tools is a lightweight AutoHotkey application that enhances OBS Studio recordings with cursor highlighting,
click animations, and recording shortcuts.
---------------------
v1.2 - 2026-10-05
Mesut Akcan
https://github.com/mesutakcan/OBS-Cursor-Tools
*/

;@Ahk2Exe-SetDescription OBS Cursor Tools
;@Ahk2Exe-SetFileVersion 1.2
;@Ahk2Exe-SetCopyright ©2026 Mesut Akcan
;@Ahk2Exe-SetMainIcon app_icon.ico
;@Ahk2Exe-AddResource app_icon_pause.ico, 206

#Requires AutoHotkey v2
#SingleInstance Force

try DllCall("SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")

#Include "lib/gdip.ahk"
#Include "lib/graphics.ahk"
#Include "lib/paste.ahk"
#Include "lib/mouse.ahk"
#Include "lib/anim.ahk"
#Include "lib/hotkeyplus.ahk"
#Include "lib/settings.ahk"

SendMode("Event")
CoordMode("Mouse", "Screen"), CoordMode("Pixel", "Screen"), CoordMode("ToolTip", "Screen")
SetKeyDelay(30)
ProcessSetPriority("AboveNormal")

SetWindowIcon(hwnd) {
	static WM_SETICON := 0x0080
	static IMAGE_ICON := 1
	static LR_LOADFROMFILE := 0x0010
	static LR_DEFAULTSIZE := 0x0040
	static hBig := 0, hSmall := 0

	if !hBig {
		if A_IsCompiled {
			hInst := DllCall("GetModuleHandle", "Ptr", 0, "Ptr")
			hBig := DllCall("LoadImageW", "Ptr", hInst, "Ptr", 159, "UInt", IMAGE_ICON,
				"Int", 0, "Int", 0, "UInt", LR_DEFAULTSIZE, "Ptr")
			hSmall := DllCall("LoadImageW", "Ptr", hInst, "Ptr", 159, "UInt", IMAGE_ICON,
				"Int", DllCall("GetSystemMetrics", "Int", 49), "Int", DllCall("GetSystemMetrics", "Int", 50),
				"UInt", 0, "Ptr")
		} else {
			hBig := DllCall("LoadImageW", "Ptr", 0, "Str", MAINICON, "UInt", IMAGE_ICON,
				"Int", 0, "Int", 0, "UInt", LR_LOADFROMFILE | LR_DEFAULTSIZE, "Ptr")
			hSmall := DllCall("LoadImageW", "Ptr", 0, "Str", MAINICON, "UInt", IMAGE_ICON,
				"Int", DllCall("GetSystemMetrics", "Int", 49), "Int", DllCall("GetSystemMetrics", "Int", 50),
				"UInt", LR_LOADFROMFILE, "Ptr")
		}
	}

	if hBig
		DllCall("SendMessage", "Ptr", hwnd, "UInt", WM_SETICON, "Ptr", 1, "Ptr", hBig)
	if hSmall
		DllCall("SendMessage", "Ptr", hwnd, "UInt", WM_SETICON, "Ptr", 0, "Ptr", hSmall)
}

if !A_IsCompiled {
	MAINICON := A_ScriptDir "\app_icon.ico"
	PAUSEICON := A_ScriptDir "\app_icon_pause.ico"
	try TraySetIcon(MAINICON, , true)
	try SetWindowIcon(A_ScriptHwnd)
}

global app := {
	ver: "1.2",
	name: "OBS Cursor Tools",
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
if Conf.syncHotkeysFromOBS
	SyncOBSHotkeys(true)

global mnuHl := "Toggle Highlighter`t" HotkeyPlus.FormatKeyToText(HK.toggleHighlight)
global mnuPauseProgram := "Pause Program"
global mnuSuspendHotkeys := "Suspend Hotkeys"
global DllCall_CallNextHookEx := DllCall.Bind("CallNextHookEx", "Ptr", 0, "Int", , "UPtr", , "Ptr", , "Ptr")

global State := {
	recording: false,
	paused: false,
	hl: false,
	alwaysShow: Conf.showOnStartup ? true : false,
	hlOverride: -1,
	Hook: "",
	mousePosHistory: [],
	mousePosLength: 5,
	prevPosIndex: 0,
	programPaused: false
}

IniReadInt(section, key, defaultValue) {
	val := ParseIntSafe(IniRead(app.iniFile, section, key, defaultValue), defaultValue)
	if (section = "Conf" && ConfRanges().Has(key))
		val := ClampConfValue(key, val)
	return val
}

IniReadFloat(section, key, defaultValue) {
	val := IniRead(app.iniFile, section, key, defaultValue)
	try return Float(val)
	return Float(defaultValue)
}

CreateTrayMenu()

RegisterHotkeys()

StartGDIPlus()
InitGraphics()
RefreshHighlight()
UpdateTrayMenu()
SetTimer(PrewarmAnimCache, -1)

HandlePause() {
	if !State.recording
		return
	State.paused := !State.paused
	if State.paused {
		saveMousePos(false)
		RefreshHighlight()
		if Conf.showRecordingNotifications
			SetTimer(() => ShowMessage("⏸ Recording paused!", "ffee00", "009e00", 175, 1000), -1000)
	} else {
		moveMousePos()
		RefreshHighlight()
		if Conf.showRecordingNotifications
			ShowMessage("▶ Recording resumed!", "ff0000", "ffee00", 175, 1000)
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
		State.paused := false
		if Conf.showRecordingNotifications
			ShowMessage("▶ Recording started!", "ff0000", "ffffff", 175, 1000)
		moveMousePos()
		RefreshHighlight()
	} else {
		saveMousePos(false)
		State.hlOverride := -1
		RefreshHighlight()
		if Conf.showRecordingNotifications
			SetTimer(() => ShowMessage("⏹ Recording stopped!", "008f00", "ffffff", 175, 2000), -1000)
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

	if State.programPaused
		A_TrayMenu.Check(mnuPauseProgram)
	else
		A_TrayMenu.UnCheck(mnuPauseProgram)

	if A_IsSuspended
		A_TrayMenu.Check(mnuSuspendHotkeys)
	else
		A_TrayMenu.UnCheck(mnuSuspendHotkeys)

	if (!A_IsCompiled)
		try TraySetIcon(A_IsSuspended ? PAUSEICON : MAINICON, , true)
}

ToggleProgramPause(*) {
	if IsObject(SettingsGuiObj)
		return

	State.programPaused := !State.programPaused
	Suspend(State.programPaused)
	RefreshHighlight()
	UpdateTrayMenu()
}

ToggleSuspendHotkeys(*) {
	if IsObject(SettingsGuiObj)
		return

	Suspend(-1)
	if !A_IsSuspended && State.programPaused {
		State.programPaused := false
		RefreshHighlight()
	}
	UpdateTrayMenu()
}

ShowHotkeys() {
	text := "Assigned Hotkeys:`n`n"
	text .= "Toggle Highlighter:`t" HotkeyPlus.FormatKeyToText(HK.toggleHighlight) "`n"
	text .= "Save Mouse Position:`t" HotkeyPlus.FormatKeyToText(HK.saveMousePos) "`n"
	text .= "Move to Last Pos:`t" HotkeyPlus.FormatKeyToText(HK.moveMousePos) "`n"
	text .= "Move to Previous Pos:`t" HotkeyPlus.FormatKeyToText(HK.movePrevMousePos) "`n"
	text .= "Start/Stop Recording:`t" HotkeyPlus.FormatKeyToText(HK.handleRecording) "`n"
	text .= "Pause/Resume Recording:`t" HotkeyPlus.FormatKeyToText(HK.handlePause) "`n"
	text .= "Type from Clipboard:`t" HotkeyPlus.FormatKeyToText(HK.typeFromClipboard)
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
	keyPart := RegExReplace(hk, "^[~*^!+#]*", "")
	if (Trim(keyPart) = "")
		return
	try {
		Hotkey(hk, callback)
	} catch as e {
		MsgBox("Could not register hotkey '" hk "':`n" e.Message, app.name, "48")
		return
	}
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

	defHK := DefaultHotkeys()
	HK := {}
	for key in HotkeyKeys()
		HK.%key% := IniRead(app.iniFile, "Hotkeys", key, defHK[key])

	defColors := DefaultColors()
	defFlags := DefaultColorFlags()
	colors := Map()
	for circleKey in ["default", "l", "m", "r"] {
		colors[circleKey] := {
			back: IniRead(app.iniFile, "Colors", ColorIniKey(circleKey, "back"), "0xFF" defColors[circleKey "_back"]),
			border: IniRead(app.iniFile, "Colors", ColorIniKey(circleKey, "border"), "0xFF" defColors[circleKey "_border"]),
			showBorder: IniRead(app.iniFile, "Colors", ColorIniKey(circleKey, "showBorder"), String(defFlags[circleKey "_showBorder"])) = "1",
			showFill: IniRead(app.iniFile, "Colors", ColorIniKey(circleKey, "showFill"), String(defFlags[circleKey "_showFill"])) = "1"
		}
	}

	defConf := DefaultConf()
	Conf := {}
	for key in ConfKeys()
		Conf.%key% := (key = "animTargetFrameTime") ? IniReadFloat("Conf", key, defConf[key]) : IniReadInt("Conf", key, defConf[key])

	Conf.ringMargin := 2
	Conf.offset := -(Conf.diameter // 2) - Conf.ringMargin
	Conf.offsetFinalX := Conf.offset + Conf.offsetX
	Conf.offsetFinalY := Conf.offset + Conf.offsetY
	Conf.circleDiameter := Max(Conf.diameter - 2 * Conf.thickness, 0)
	Conf.circlePositionOffset := (Conf.diameter - Conf.circleDiameter) // 2
	Conf.startTransparency := Conf.animTransparency
}

CreateTrayMenu() {
	A_TrayMenu.Add("About", (*) => ShowAbout())
	A_TrayMenu.Add("Hotkeys", (*) => ShowHotkeys())
	A_TrayMenu.Add("Settings", (*) => ShowSettingsGui())
	A_TrayMenu.Add("Sync Hotkeys from OBS", (*) => ManualSyncHotkeysFromOBS())
	A_TrayMenu.Add()
	A_TrayMenu.Add(mnuPauseProgram, (*) => ToggleProgramPause())
	A_TrayMenu.Add(mnuSuspendHotkeys, (*) => ToggleSuspendHotkeys())
	A_TrayMenu.Add()
	A_TrayMenu.Add(mnuHl, (*) => ToggleHighlight())
	A_TrayMenu.Add("Save mouse position`t" HotkeyPlus.FormatKeyToText(HK.saveMousePos), (*) => saveMousePos())
	A_TrayMenu.Add("Move mouse to last position`t" HotkeyPlus.FormatKeyToText(HK.moveMousePos), (*) => moveMousePos())
	A_TrayMenu.Add("Move mouse to previous position`t" HotkeyPlus.FormatKeyToText(HK.movePrevMousePos), (*) => movePrevMousePos())
	A_TrayMenu.Add()
	A_TrayMenu.Add("Start/stop recording`t" HotkeyPlus.FormatKeyToText(HK.handleRecording), (*) => HandleRecording())
	A_TrayMenu.Add("Pause/resume recording`t" HotkeyPlus.FormatKeyToText(HK.handlePause), (*) => HandlePause())
	A_TrayMenu.Add()
	A_TrayMenu.Add("Type from clipboard`t" HotkeyPlus.FormatKeyToText(HK.typeFromClipboard), (*) => TypeFromClipboard())
	A_TrayMenu.Add()
	A_TrayMenu.Add("Restart", (*) => Reload())
	A_TrayMenu.Add("Exit", (*) => ExitApp())
}

ShowAbout(*) {
	m := app.name " v" app.ver "`n`n"
	m .= app.name " is a lightweight presentation and recording assistant that enhances "
	m .= "your video tutorials with real-time mouse highlighting, visual click animations, "
	m .= "and automatic OBS hotkey synchronization.`n`n"
	m .= "©2026 Mesut Akcan`n"
	m .= "mesutakcan.blogspot.com`n"
	m .= "youtube.com/mesutakcan`n"
	m .= app.github
	MsgBox(m, "About", "IconI")
}

OnExit(CleanupResources)

ReadOBSHotkeys() {
	result := { error: "", rec: "", pz: "", problems: [] }
	obsBase := A_AppData "\obs-studio\basic"
	profileDir := GetActiveOBSProfileDir(obsBase)
	if !profileDir {
		result.error := "OBS profile folder was not found"
		return result
	}

	iniPath := obsBase "\profiles\" profileDir "\basic.ini"
	if !FileExist(iniPath) {
		result.error := "OBS profile file was not found (" profileDir ")"
		return result
	}

	startCombo := ParseOBSHotkey(IniRead(iniPath, "Hotkeys", "OBSBasic.StartRecording", ""))
	stopCombo := ParseOBSHotkey(IniRead(iniPath, "Hotkeys", "OBSBasic.StopRecording", ""))
	pauseCombo := ParseOBSHotkey(IniRead(iniPath, "Hotkeys", "OBSBasic.PauseRecording", ""))
	unpauseCombo := ParseOBSHotkey(IniRead(iniPath, "Hotkeys", "OBSBasic.UnpauseRecording", ""))

	if (startCombo && stopCombo && startCombo != stopCombo)
		result.problems.Push("'Start Recording' (" startCombo ") and 'Stop Recording' (" stopCombo ") use different keys in OBS.")
	if (pauseCombo && unpauseCombo && pauseCombo != unpauseCombo)
		result.problems.Push("'Pause Recording' (" pauseCombo ") and 'Unpause Recording' (" unpauseCombo ") use different keys in OBS.")

	result.rec := startCombo ? startCombo : stopCombo
	result.pz := pauseCombo ? pauseCombo : unpauseCombo
	return result
}

SyncOBSHotkeys(silent := false) {
	global HK
	try {
		obs := ReadOBSHotkeys()
		if obs.error {
			if !silent
				AnnounceActiveHotkeys(obs.error "; values from settings.ini will be used.")
			return false
		}

		if obs.problems.Length {
			msg := "There is an OBS hotkey mismatch that needs to be fixed:`n`n"
			for p in obs.problems
				msg .= "  - " p "`n"
			msg .= "`nBoth keys in each pair must be the SAME for this script to work.`nFix it in OBS → Settings → Hotkeys.`nUntil then, the script will continue using the previous values from settings.ini."
			MsgBox(msg, "OBS Hotkey Mismatch", "48")
			if !silent
				AnnounceActiveHotkeys("Previous values from settings.ini are being used because of the OBS mismatch.")
			return false
		}

		changed := false
		if (obs.rec && obs.rec != HK.handleRecording) {
			HK.handleRecording := obs.rec
			IniWrite(obs.rec, app.iniFile, "Hotkeys", "handleRecording")
			changed := true
		}
		if (obs.pz && obs.pz != HK.handlePause) {
			HK.handlePause := obs.pz
			IniWrite(obs.pz, app.iniFile, "Hotkeys", "handlePause")
			changed := true
		}

		if !silent
			AnnounceActiveHotkeys(changed ? "Synchronized with OBS (settings.ini updated)." : "In sync with OBS.")
		return changed
	} catch as e {
		if !silent
			AnnounceActiveHotkeys("Error while checking OBS hotkeys: " e.Message ". Values from settings.ini will be used.")
		return false
	}
}

ManualSyncHotkeysFromOBS(*) {
	changed := SyncOBSHotkeys()
	if changed {
		result := MsgBox("Restart now to apply the updated hotkeys?", app.name, "YesNo Iconi")
		if result = "Yes"
			Reload()
	}
}

AnnounceActiveHotkeys(statusLine) {
	msg := "Start/Stop Recording:`t" HotkeyPlus.FormatKeyToText(HK.handleRecording) "`n"
	msg .= "Pause/Resume Recording:`t" HotkeyPlus.FormatKeyToText(HK.handlePause) "`n`n"
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
	if RegExMatch(raw, '"command"\s*:\s*true')
		combo .= "#"
	return combo . keyName
}

ConvertOBSKeyName(obsKey) {
	static keyMap := Map(
		"NUM0", "Numpad0", "NUM1", "Numpad1", "NUM2", "Numpad2", "NUM3", "Numpad3", "NUM4", "Numpad4",
		"NUM5", "Numpad5", "NUM6", "Numpad6", "NUM7", "Numpad7", "NUM8", "Numpad8", "NUM9", "Numpad9",
		"PAUSE", "Pause", "INSERT", "Insert", "DELETE", "Delete", "HOME", "Home", "END", "End",
		"PAGEUP", "PgUp", "PAGEDOWN", "PgDn", "SPACE", "Space", "ESCAPE", "Escape", "TAB", "Tab",
		"NUMASTERISK", "NumpadMult", "NUMSLASH", "NumpadDiv", "NUMPLUS", "NumpadAdd", "NUMMINUS", "NumpadSub",
		"NUMPERIOD", "NumpadDot", "PRINT", "PrintScreen", "SCROLLLOCK", "ScrollLock", "NUMLOCK", "NumLock", "CAPSLOCK", "CapsLock",
		"LEFT", "Left", "RIGHT", "Right", "UP", "Up", "DOWN", "Down",
		"BACKSPACE", "Backspace", "RETURN", "Enter", "ENTER", "Enter",
		"PERIOD", ".", "COMMA", ",", "MINUS", "-", "EQUAL", "=", "SLASH", "/",
		"BRACKETLEFT", "[", "BRACKETRIGHT", "]", "SEMICOLON", ";", "APOSTROPHE", "'",
		"BACKSLASH", "\", "GRAVE", "``"
	)
	upper := StrUpper(obsKey)
	if RegExMatch(upper, "^F([1-9]|1\d|2[0-4])$")
		return upper
	if keyMap.Has(upper)
		return keyMap[upper]
	if StrLen(obsKey) = 1
		return obsKey
	return ""
}