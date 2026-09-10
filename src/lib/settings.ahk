#Requires AutoHotkey v2

global SettingsCtrls := Map()
global SettingsGuiObj := ""
global PreviewApp := ""
global PreviewColor := ""
global PREVIEW_APP_W := 210
global PREVIEW_APP_H := 150
global PREVIEW_COLOR_W := 440
global PREVIEW_COLOR_H := 100
global SettingsPrevHl := false
global SettingsPrevSuspend := false
global PreviewBgLevel := 43
global HotkeyLabels := Map()
global HotkeyWarningText := ""
global SettingsBtnSave := ""
global SettingsTab := ""

ShowSettingsGui(*) {
	global SettingsGuiObj, SettingsCtrls, PreviewApp, PreviewColor, SettingsPrevHl, SettingsPrevSuspend

	if IsObject(SettingsGuiObj) {
		SettingsGuiObj.Show()
		return
	}

	SettingsPrevSuspend := A_IsSuspended
	Suspend(true)
	SettingsPrevHl := State.hl
	State.hl := false
	showHighlight(false)
	UpdateTrayMenu()

	SettingsCtrls := Map()
	SettingsGuiObj := Gui("+AlwaysOnTop", app.name " - Settings")
	SettingsGuiObj.Opt("+OwnDialogs")
	SettingsGuiObj.SetFont("s10", "Segoe UI")
	SettingsGuiObj.OnEvent("Close", (*) => CloseSettingsGui())
	SettingsGuiObj.OnEvent("Escape", (*) => CloseSettingsGui())

	global SettingsTab
	tab := SettingsGuiObj.Add("Tab3", "x10 y10 w500 h457", ["Appearance", "Colors", "Hotkeys"])
	SettingsTab := tab

	tab.UseTab(3)
	global HotkeyLabels
	HotkeyLabels := Map()

	SettingsCtrls["syncHotkeysFromOBS"] := SettingsGuiObj.Add("CheckBox", "x20 y40 w460",
		"Automatically sync Start/Stop and Pause/Resume hotkeys from OBS")
	SettingsCtrls["syncHotkeysFromOBS"].Value := IniRead(app.iniFile, "Conf", "syncHotkeysFromOBS",
		Conf.syncHotkeysFromOBS ? "1" : "0") = "1" ? 1 : 0
	SettingsCtrls["syncHotkeysFromOBS"].OnEvent("Click", (*) => UpdateSyncHotkeysState())

	btnSyncNow := SettingsGuiObj.Add("Button", "x30 y64 w100 h24", "Sync Now")
	btnSyncNow.OnEvent("Click", (*) => SyncNowFromGui())
	SettingsGuiObj.Add("Text", "x+5 w350 c666666", "Reads the current Start/Stop and Pause/Resume keys from OBS.")

	hkList := [
		["handlePause", "Pause/Resume Recording"],
		["handleRecording", "Start/Stop Recording"],
		["toggleHighlight", "Toggle Highlighter"],
		["moveMousePos", "Move to Saved Position"],
		["movePrevMousePos", "Move to Previous Position"],
		["saveMousePos", "Save Mouse Position"],
		["typeFromClipboard", "Type from Clipboard"]
	]
	y := 115
	for item in hkList {
		key := item[1], label := item[2]
		HotkeyLabels[key] := label
		SettingsGuiObj.Add("Text", "x30 y" y " w190", label)
		initialVal := IniRead(app.iniFile, "Hotkeys", key, HK.%key%)
		hkCtrl := SettingsGuiObj.AddHotkeyPlus("x230 y" (y - 3) " w210", initialVal)
		hkCtrl.OnEvent("Change", (*) => UpdateHotkeyConflictWarning())
		SettingsCtrls[key] := hkCtrl
		y += 32
	}
	global HotkeyWarningText
	HotkeyWarningText := SettingsGuiObj.Add("Text", "x30 y" (y + 5) " w440 h40 cRed", "")

	UpdateSyncHotkeysState()

	tab.UseTab(1)

	SettingsCtrls["showOnStartup"] := SettingsGuiObj.Add("CheckBox", "x20 y38", "Show Highlighter on Startup")
	SettingsCtrls["showOnStartup"].Value := IniRead(app.iniFile, "Conf", "showOnStartup",
		Conf.showOnStartup ? "1" : "0") = "1" ? 1 : 0

	SettingsCtrls["showRecordingNotifications"] := SettingsGuiObj.Add("CheckBox", "x20 y60",
		"Show Recording Start/Stop/Pause Notifications")
	SettingsCtrls["showRecordingNotifications"].Value := IniRead(app.iniFile, "Conf", "showRecordingNotifications",
		Conf.showRecordingNotifications ? "1" : "0") = "1" ? 1 : 0

	SettingsCtrls["showMousePosNotifications"] := SettingsGuiObj.Add("CheckBox", "x20 y82",
		"Show Mouse Position Save/Move Notifications")
	SettingsCtrls["showMousePosNotifications"].Value := IniRead(app.iniFile, "Conf", "showMousePosNotifications",
		Conf.showMousePosNotifications ? "1" : "0") = "1" ? 1 : 0

	SettingsGuiObj.Add("GroupBox", "x20 y110 w230 h150", "Ring")
	PreviewApp := SettingsGuiObj.Add("Picture", "x270 y110 w" PREVIEW_APP_W " h" PREVIEW_APP_H " Border", "")

	ry := 138
	SettingsGuiObj.Add("Text", "x35 y" ry " w120", "Diameter (px)")
	SettingsCtrls["diameter"] := AddClampedIntEdit(SettingsGuiObj, 165, ry - 3, 50,
		IniRead(app.iniFile, "Conf", "diameter", Conf.diameter), 4, 500)
	SettingsCtrls["diameter"].OnEvent("Change", (*) => UpdatePreviews())
	SettingsCtrls["diameter"].OnEvent("LoseFocus", (*) => ClampThicknessToDiameter())
	ry += 27
	SettingsGuiObj.Add("Text", "x35 y" ry " w120", "Thickness (px)")
	SettingsCtrls["thickness"] := AddClampedIntEdit(SettingsGuiObj, 165, ry - 3, 50,
		IniRead(app.iniFile, "Conf", "thickness", Conf.thickness), 1, 250)
	SettingsCtrls["thickness"].OnEvent("Change", (*) => UpdatePreviews())
	SettingsCtrls["thickness"].OnEvent("LoseFocus", (*) => ClampThicknessToDiameter())
	ry += 27
	SettingsGuiObj.Add("Text", "x35 y" ry " w120", "Offset X (px)")
	SettingsCtrls["offsetX"] := AddClampedIntEdit(SettingsGuiObj, 165, ry - 3, 50,
		IniRead(app.iniFile, "Conf", "offsetX", Conf.offsetX), -50, 50)
	SettingsCtrls["offsetX"].OnEvent("Change", (*) => UpdatePreviews())
	ry += 27
	SettingsGuiObj.Add("Text", "x35 y" ry " w120", "Offset Y (px)")
	SettingsCtrls["offsetY"] := AddClampedIntEdit(SettingsGuiObj, 165, ry - 3, 50,
		IniRead(app.iniFile, "Conf", "offsetY", Conf.offsetY), -50, 50)
	SettingsCtrls["offsetY"].OnEvent("Change", (*) => UpdatePreviews())

	SettingsGuiObj.Add("GroupBox", "x20 y270 w460 h185", "Animation")

	ay := 298
	SettingsGuiObj.Add("Text", "x35 y" ay " w220", "Steps")
	SettingsCtrls["steps"] := AddClampedIntEdit(SettingsGuiObj, 270, ay - 3, 60,
		IniRead(app.iniFile, "Conf", "steps", Conf.steps), 1, 200)
	ay += 25
	SettingsGuiObj.Add("Text", "x35 y" ay " w220", "Start Diameter (px)")
	SettingsCtrls["startDiameter"] := AddClampedIntEdit(SettingsGuiObj, 270, ay - 3, 60,
		IniRead(app.iniFile, "Conf", "startDiameter", Conf.startDiameter), 1, 500)
	ay += 25
	SettingsGuiObj.Add("Text", "x35 y" ay " w220", "End Diameter (px)")
	SettingsCtrls["endDiameter"] := AddClampedIntEdit(SettingsGuiObj, 270, ay - 3, 60,
		IniRead(app.iniFile, "Conf", "endDiameter", Conf.endDiameter), 1, 500)
	ay += 25
	SettingsGuiObj.Add("Text", "x35 y" ay " w220", "Transparency (0-255)")
	SettingsCtrls["animTransparency"] := AddClampedIntEdit(SettingsGuiObj, 270, ay - 3, 60,
		IniRead(app.iniFile, "Conf", "animTransparency", Conf.animTransparency), 0, 255)
	ay += 25
	SettingsGuiObj.Add("Text", "x35 y" ay " w220", "End Transparency (0-255)")
	SettingsCtrls["endTransparency"] := AddClampedIntEdit(SettingsGuiObj, 270, ay - 3, 60,
		IniRead(app.iniFile, "Conf", "endTransparency", Conf.endTransparency), 0, 255)
	ay += 25
	SettingsGuiObj.Add("Text", "x35 y" ay " w220", "Frame Time (ms)")
	frameTimeRaw := IniRead(app.iniFile, "Conf", "animTargetFrameTime", Conf.animTargetFrameTime)
	frameTimeDisplay := frameTimeRaw
	parsedFT := ""
	try parsedFT := Float(frameTimeRaw)
	if (parsedFT != "" && InStr(frameTimeRaw, ".") && StrLen(RegExReplace(frameTimeRaw, "^[^.]*\.", "")) > 4)
		frameTimeDisplay := FormatFrameTime(parsedFT)
	SettingsCtrls["animTargetFrameTime"] := SettingsGuiObj.Add("Edit", "x270 y" (ay - 3) " w60", frameTimeDisplay)
	SettingsCtrls["animTargetFrameTime"].OnEvent("LoseFocus", (*) => ClampFrameTimeEdit())


	tab.UseTab(2)
	SettingsGuiObj.Add("Text", "x30 y45 w230", "Ring Transparency (0-255)")
	SettingsCtrls["ringTransparency"] := AddClampedIntEdit(SettingsGuiObj, 270, 42, 60,
		IniRead(app.iniFile, "Conf", "ringTransparency", Conf.ringTransparency), 0, 255)
	SettingsCtrls["ringTransparency"].OnEvent("Change", (*) => UpdatePreviews())
	SettingsGuiObj.Add("Text", "x30 y73 w230", "Inner Circle Transparency (0-255)")
	SettingsCtrls["circleTransparency"] := AddClampedIntEdit(SettingsGuiObj, 270, 70, 60,
		IniRead(app.iniFile, "Conf", "circleTransparency", Conf.circleTransparency), 0, 255)
	SettingsCtrls["circleTransparency"].OnEvent("Change", (*) => UpdatePreviews())

	colorList := ["default", "l", "m", "r"]
	colorLabels := Map("default", "Default", "l", "Left Click", "m", "Middle Click", "r", "Right Click")
	y := 115
	for key in colorList {
		label := colorLabels[key]
		SettingsGuiObj.Add("Text", "x30 y" y " w80", label)

		chkBorder := SettingsGuiObj.Add("CheckBox", "x115 y" (y - 2) " w70", "Border")
		chkBorder.Value := IniRead(app.iniFile, "Colors", ColorIniKey(key, "showBorder"),
			colors[key].showBorder ? "1" : "0") = "1" ? 1 : 0
		SettingsCtrls[key "_showBorder"] := chkBorder
		chkBorder.OnEvent("Click", (*) => UpdatePreviews())

		borderVal := ColorToRGBHex(IniRead(app.iniFile, "Colors", ColorIniKey(key, "border"), colors[key].border))
		borderEdit := SettingsGuiObj.Add("Edit", "x188 y" (y - 3) " w55", borderVal)
		SettingsCtrls[key "_border"] := borderEdit
		borderSwatch := MakeSwatch(SettingsGuiObj, 247, y - 3, borderVal)
		SettingsCtrls[key "_border_swatch"] := borderSwatch
		btnBorder := SettingsGuiObj.Add("Button", "x273 y" (y - 4) " w26 h22", "…")
		btnBorder.OnEvent("Click", PickColorHandler.Bind(borderEdit, borderSwatch))
		borderEdit.OnEvent("Change", ColorEditChanged.Bind(borderEdit, borderSwatch))
		borderEdit.OnEvent("LoseFocus", PadColorEdit.Bind(borderEdit, borderSwatch))

		chkFill := SettingsGuiObj.Add("CheckBox", "x309 y" (y - 2) " w45", "Fill")
		chkFill.Value := IniRead(app.iniFile, "Colors", ColorIniKey(key, "showFill"),
			colors[key].showFill ? "1" : "0") = "1" ? 1 : 0
		SettingsCtrls[key "_showFill"] := chkFill
		chkFill.OnEvent("Click", (*) => UpdatePreviews())

		backVal := ColorToRGBHex(IniRead(app.iniFile, "Colors", ColorIniKey(key, "back"), colors[key].back))
		backEdit := SettingsGuiObj.Add("Edit", "x358 y" (y - 3) " w55", backVal)
		SettingsCtrls[key "_back"] := backEdit
		backSwatch := MakeSwatch(SettingsGuiObj, 417, y - 3, backVal)
		SettingsCtrls[key "_back_swatch"] := backSwatch
		btnFill := SettingsGuiObj.Add("Button", "x443 y" (y - 4) " w26 h22", "…")
		btnFill.OnEvent("Click", PickColorHandler.Bind(backEdit, backSwatch))
		backEdit.OnEvent("Change", ColorEditChanged.Bind(backEdit, backSwatch))
		backEdit.OnEvent("LoseFocus", PadColorEdit.Bind(backEdit, backSwatch))

		y += 36
	}

	PreviewColor := SettingsGuiObj.Add("Picture", "x30 y" (y + 5) " w" PREVIEW_COLOR_W " h" PREVIEW_COLOR_H " Border", "")

	bgY := y + PREVIEW_COLOR_H + 20
	SettingsGuiObj.Add("Text", "x30 y" bgY " w180", "Preview Background")
	bgSlider := SettingsGuiObj.Add("Slider", "x210 y" (bgY - 2) " w260 Range0-255 TickInterval51", PreviewBgLevel)
	bgSlider.OnEvent("Change", OnBgSliderChange)

	tab.UseTab()
	global SettingsBtnSave
	btnReset := SettingsGuiObj.Add("Button", "x15 y477 w120 h30", "Reset to Defaults")
	btnLoad := SettingsGuiObj.Add("Button", "x140 y477 w70 h30", "Load...")
	SettingsBtnSave := SettingsGuiObj.Add("Button", "x215 y477 w70 h30 Default", "Save")
	btnSaveAs := SettingsGuiObj.Add("Button", "x290 y477 w100 h30", "Save As...")
	btnCancel := SettingsGuiObj.Add("Button", "x395 y477 w95 h30", "Cancel")
	btnReset.OnEvent("Click", (*) => ResetToDefaults())
	btnLoad.OnEvent("Click", (*) => LoadProfile())
	SettingsBtnSave.OnEvent("Click", (*) => SaveSettingsGui())
	btnSaveAs.OnEvent("Click", (*) => SaveAsProfile())
	btnCancel.OnEvent("Click", (*) => CloseSettingsGui())

	SettingsGuiObj.Show("w520 h522")
	UpdatePreviews()
	UpdateHotkeyConflictWarning()
}

AddClampedIntEdit(gui, x, y, w, val, minVal, maxVal) {
	opts := (minVal < 0) ? "" : " Number"
	editCtrl := gui.Add("Edit", "x" x " y" y " w" w opts, val)
	if (minVal < 0)
		editCtrl.OnEvent("Change", FilterSignedIntEdit.Bind(editCtrl))
	udY := y - 1
	gui.Add("UpDown", "x-2 y" udY " w18 Range" minVal "-" maxVal " AltSubmit", val)
	return editCtrl
}

FilterSignedIntEdit(editCtrl, *) {
	val := editCtrl.Value
	isNeg := SubStr(val, 1, 1) = "-"
	digits := RegExReplace(val, "[^0-9]")
	clean := isNeg ? "-" digits : digits
	if clean != val
		editCtrl.Value := clean
}

ClampThicknessToDiameter() {
	global SettingsCtrls
	if !IsObject(SettingsCtrls) || !SettingsCtrls.Has("diameter") || !SettingsCtrls.Has("thickness")
		return
	diameter := ParseIntSafe(SettingsCtrls["diameter"].Value, Conf.diameter)
	maxThickness := Max(diameter // 2, 1)
	thickness := ParseIntSafe(SettingsCtrls["thickness"].Value, Conf.thickness)
	if thickness > maxThickness {
		SettingsCtrls["thickness"].Value := maxThickness
		UpdatePreviews()
	}
}

OnBgSliderChange(ctrl, *) {
	global PreviewBgLevel
	PreviewBgLevel := ctrl.Value
	UpdatePreviews()
}

UpdateSyncHotkeysState() {
	global SettingsCtrls
	if !IsObject(SettingsCtrls) || !SettingsCtrls.Has("syncHotkeysFromOBS")
		return
	on := SettingsCtrls["syncHotkeysFromOBS"].Value
	for key in ["handlePause", "handleRecording"] {
		if SettingsCtrls.Has(key)
			SettingsCtrls[key].Enabled := !on
	}
}

AssignHotkeyValue(key, val) {
	global SettingsCtrls
	SettingsCtrls[key].Value := val
}

SyncNowFromGui() {
	global SettingsCtrls, SettingsGuiObj
	SettingsGuiObj.Opt("+OwnDialogs")
	obsBase := A_AppData "\obs-studio\basic"
	profileDir := GetActiveOBSProfileDir(obsBase)
	if !profileDir {
		MsgBox("OBS profile folder was not found.", app.name, "Iconx")
		return
	}

	iniPath := obsBase "\profiles\" profileDir "\basic.ini"
	if !FileExist(iniPath) {
		MsgBox("OBS profile file was not found (" profileDir ").", app.name, "Iconx")
		return
	}

	startCombo := ParseOBSHotkey(IniRead(iniPath, "Hotkeys", "OBSBasic.StartRecording", ""))
	stopCombo := ParseOBSHotkey(IniRead(iniPath, "Hotkeys", "OBSBasic.StopRecording", ""))
	pauseCombo := ParseOBSHotkey(IniRead(iniPath, "Hotkeys", "OBSBasic.PauseRecording", ""))
	unpauseCombo := ParseOBSHotkey(IniRead(iniPath, "Hotkeys", "OBSBasic.UnpauseRecording", ""))

	problems := []
	if (startCombo && stopCombo && startCombo != stopCombo)
		problems.Push("'Start Recording' (" startCombo ") and 'Stop Recording' (" stopCombo ") use different keys in OBS.")
	if (pauseCombo && unpauseCombo && pauseCombo != unpauseCombo)
		problems.Push("'Pause Recording' (" pauseCombo ") and 'Unpause Recording' (" unpauseCombo ") use different keys in OBS.")

	if problems.Length {
		msg := "There is an OBS hotkey mismatch that needs to be fixed:`n`n"
		for p in problems
			msg .= "• " p "`n"
		msg .= "`nFix it in OBS → Settings → Hotkeys, then try again."
		MsgBox(msg, app.name, "Iconx")
		return
	}

	recCombo := startCombo ? startCombo : stopCombo
	pzCombo := pauseCombo ? pauseCombo : unpauseCombo

	if !recCombo && !pzCombo {
		MsgBox("No Start/Stop or Pause/Resume hotkeys are assigned in OBS.", app.name, "Iconx")
		return
	}

	if recCombo
		AssignHotkeyValue("handleRecording", recCombo)
	if pzCombo
		AssignHotkeyValue("handlePause", pzCombo)

	UpdateHotkeyConflictWarning()
	MsgBox("Synced from OBS. Click Save to keep these values.", app.name, "Iconi")
}

CheckHotkeyConflicts() {
	global SettingsCtrls, HotkeyLabels
	seen := Map()
	conflicts := []
	for key, label in HotkeyLabels {
		val := Trim(SettingsCtrls[key].Value)
		if val = ""
			continue
		if seen.Has(val)
			conflicts.Push(seen[val] " / " label " → " val)
		else
			seen[val] := label
	}
	return conflicts
}

UpdateHotkeyConflictWarning() {
	global HotkeyWarningText, SettingsBtnSave
	conflicts := CheckHotkeyConflicts()
	if conflicts.Length = 0 {
		if IsObject(HotkeyWarningText)
			HotkeyWarningText.Text := ""
		if IsObject(SettingsBtnSave)
			SettingsBtnSave.Enabled := true
		return
	}
	msg := "Conflicting hotkeys:`n"
	for c in conflicts
		msg .= "• " c "`n"
	if IsObject(HotkeyWarningText)
		HotkeyWarningText.Text := msg
	if IsObject(SettingsBtnSave)
		SettingsBtnSave.Enabled := false
}

DefaultHotkeys() {
	static m := Map(
		"toggleHighlight", "^+F8",
		"moveMousePos", "^Numpad4",
		"movePrevMousePos", "^Numpad7",
		"saveMousePos", "^Numpad6",
		"handlePause", "Pause",
		"handleRecording", "^Numpad0",
		"typeFromClipboard", "^."
	)
	return m
}

DefaultConf() {
	static m := Map(
		"diameter", 48,
		"thickness", 4,
		"ringTransparency", 190,
		"circleTransparency", 170,
		"animTransparency", 255,
		"endTransparency", 0,
		"steps", 15,
		"startDiameter", 10,
		"endDiameter", 50,
		"animTargetFrameTime", "16.67",
		"offsetX", 0,
		"offsetY", 0,
		"showOnStartup", 0,
		"showRecordingNotifications", 1,
		"showMousePosNotifications", 1,
		"syncHotkeysFromOBS", 1
	)
	return m
}

DefaultColors() {
	static m := Map(
		"default_border", "00FFFF", "default_back", "00FFFF",
		"l_border", "00FFFF", "l_back", "FF0000",
		"m_border", "FF00FF", "m_back", "00FFFF",
		"r_border", "FF0000", "r_back", "00FF00"
	)
	return m
}

DefaultColorFlags() {
	static m := Map(
		"default_showBorder", 1, "default_showFill", 0,
		"l_showBorder", 1, "l_showFill", 1,
		"m_showBorder", 1, "m_showFill", 1,
		"r_showBorder", 1, "r_showFill", 1
	)
	return m
}

ResetToDefaults() {
	global SettingsCtrls

	for key, val in DefaultHotkeys()
		AssignHotkeyValue(key, val)
	UpdateHotkeyConflictWarning()

	for key, val in DefaultConf()
		SettingsCtrls[key].Value := val
	UpdateSyncHotkeysState()

	for key, hex6 in DefaultColors() {
		SettingsCtrls[key].Value := hex6
		SetSwatchColor(SettingsCtrls[key "_swatch"], hex6)
	}

	for key, val in DefaultColorFlags()
		SettingsCtrls[key].Value := val

	UpdatePreviews()
}

MakeSwatch(gui, x, y, hex6) {
	ctrl := gui.Add("Progress", "x" x " y" y " w22 h22 Range0-1 -Smooth Border", 1)
	ctrl.Opt("c" hex6 " Background" hex6)
	return ctrl
}

CloseSettingsGui() {
	global SettingsGuiObj, PreviewApp, PreviewColor, SettingsPrevHl, SettingsPrevSuspend, SettingsTab
	if IsObject(SettingsGuiObj) {
		SettingsGuiObj.Destroy()
		SettingsGuiObj := ""
		SettingsTab := ""
		PreviewApp := ""
		PreviewColor := ""
	}
	State.hl := SettingsPrevHl
	showHighlight(State.hl)
	Suspend(SettingsPrevSuspend ? true : false)
	UpdateTrayMenu()
}

ColorIniKey(key, part) {
	static m := Map(
		"default_border", "defaultBorder", "default_back", "defaultBack",
		"default_showBorder", "defaultShowBorder", "default_showFill", "defaultShowFill",
		"l_border", "leftBorder", "l_back", "leftBack",
		"l_showBorder", "leftShowBorder", "l_showFill", "leftShowFill",
		"m_border", "middleBorder", "m_back", "middleBack",
		"m_showBorder", "middleShowBorder", "m_showFill", "middleShowFill",
		"r_border", "rightBorder", "r_back", "rightBack",
		"r_showBorder", "rightShowBorder", "r_showFill", "rightShowFill"
	)
	return m[key "_" part]
}

ColorToRGBHex(argbWithPrefix) {
	s := Trim(argbWithPrefix)
	if (SubStr(s, 1, 2) = "0x" || SubStr(s, 1, 2) = "0X")
		s := SubStr(s, 3)
	s := StrUpper(s)
	if StrLen(s) = 8
		s := SubStr(s, 3)
	if !RegExMatch(s, "^[0-9A-F]{1,6}$")
		return "000000"
	loop 6 - StrLen(s)
		s := "0" s
	return s
}

CleanHexInput(s) {
	s := StrUpper(RegExReplace(s, "[^0-9A-Fa-f]"))
	if StrLen(s) > 6
		s := SubStr(s, 1, 6)
	return s
}

PadColorEdit(editCtrl, swatchCtrl, *) {
	clean := CleanHexInput(editCtrl.Value)
	if clean = ""
		return
	loop 6 - StrLen(clean)
		clean := "0" clean
	editCtrl.Value := clean
	SetSwatchColor(swatchCtrl, clean)
	UpdatePreviews()
}

ColorEditChanged(editCtrl, swatchCtrl, *) {
	clean := CleanHexInput(editCtrl.Value)
	if clean != editCtrl.Value
		editCtrl.Value := clean
	SetSwatchColor(swatchCtrl, clean)
	UpdatePreviews()
}

SetSwatchColor(swatchCtrl, hex6) {
	clean := hex6
	loop 6 - StrLen(clean)
		clean := "0" clean
	swatchCtrl.Opt("c" clean " Background" clean)
}

PickColorHandler(editCtrl, swatchCtrl, *) {
	picked := PickColor(editCtrl.Value)
	if picked != "" {
		editCtrl.Value := picked
		SetSwatchColor(swatchCtrl, picked)
		UpdatePreviews()
	}
}

PickColor(hex6) {
	static customColors := Buffer(16 * 4, 0)
	clean := CleanHexInput(hex6)
	loop 6 - StrLen(clean)
		clean := "0" clean
	rgb := Integer("0x" SubStr(clean, 5, 2) SubStr(clean, 3, 2) SubStr(clean, 1, 2))
	cc := Buffer(9 * A_PtrSize, 0)
	NumPut("UInt", cc.Size, cc, 0)
	NumPut("Ptr", 0, cc, A_PtrSize)
	NumPut("UInt", rgb, cc, A_PtrSize * 3)
	NumPut("Ptr", customColors.Ptr, cc, A_PtrSize * 4)
	NumPut("UInt", 0x1 | 0x2, cc, A_PtrSize * 5)
	if !DllCall("comdlg32\ChooseColorW", "Ptr", cc, "Int")
		return ""
	result := NumGet(cc, A_PtrSize * 3, "UInt")
	r := result & 0xFF
	g := (result >> 8) & 0xFF
	b := (result >> 16) & 0xFF
	return Format("{:02X}{:02X}{:02X}", r, g, b)
}

ParseIntSafe(val, fallback) {
	try return Integer(val)
	return fallback
}

ParseFloatSafe(val, fallback) {
	try return Float(val)
	return fallback
}

FormatFrameTime(val) {
	s := Format("{:.3f}", val)
	s := RegExReplace(s, "0+$")
	s := RegExReplace(s, "\.$", ".0")
	return s
}

ClampFrameTimeEdit() {
	global SettingsCtrls
	if !IsObject(SettingsCtrls) || !SettingsCtrls.Has("animTargetFrameTime")
		return
	raw := Trim(SettingsCtrls["animTargetFrameTime"].Value)
	parsed := ""
	try parsed := Float(raw)
	if (parsed == "" || parsed < 1 || parsed > 1000) {
		val := (parsed == "") ? Conf.animTargetFrameTime : Max(1, Min(parsed, 1000))
		SettingsCtrls["animTargetFrameTime"].Value := FormatFrameTime(val)
	}
}

ColorTextToARGB(text, fallback) {
	clean := CleanHexInput(text)
	if clean = ""
		clean := ColorToRGBHex(fallback)
	loop 6 - StrLen(clean)
		clean := "0" clean
	return Integer("0xFF" clean)
}

UpdatePreviews() {
	global SettingsCtrls, PreviewApp, PreviewColor
	if !IsObject(SettingsCtrls) || SettingsCtrls.Count = 0
		return

	diameter := ParseIntSafe(SettingsCtrls["diameter"].Value, Conf.diameter)
	thickness := Min(ParseIntSafe(SettingsCtrls["thickness"].Value, Conf.thickness), Max(diameter // 2, 1))
	ringAlpha := ParseIntSafe(SettingsCtrls["ringTransparency"].Value, Conf.ringTransparency)
	circleAlpha := ParseIntSafe(SettingsCtrls["circleTransparency"].Value, Conf.circleTransparency)
	offsetX := ParseIntSafe(SettingsCtrls["offsetX"].Value, Conf.offsetX)
	offsetY := ParseIntSafe(SettingsCtrls["offsetY"].Value, Conf.offsetY)

	defBorder := ColorTextToARGB(SettingsCtrls["default_border"].Value, colors["default"].border)
	defBack := ColorTextToARGB(SettingsCtrls["default_back"].Value, colors["default"].back)
	lBorder := ColorTextToARGB(SettingsCtrls["l_border"].Value, colors["l"].border)
	lBack := ColorTextToARGB(SettingsCtrls["l_back"].Value, colors["l"].back)
	mBorder := ColorTextToARGB(SettingsCtrls["m_border"].Value, colors["m"].border)
	mBack := ColorTextToARGB(SettingsCtrls["m_back"].Value, colors["m"].back)
	rBorder := ColorTextToARGB(SettingsCtrls["r_border"].Value, colors["r"].border)
	rBack := ColorTextToARGB(SettingsCtrls["r_back"].Value, colors["r"].back)

	defRingAlpha := SettingsCtrls["default_showBorder"].Value ? ringAlpha : 0
	defCircleAlpha := SettingsCtrls["default_showFill"].Value ? circleAlpha : 0
	lRingAlpha := SettingsCtrls["l_showBorder"].Value ? ringAlpha : 0
	lCircleAlpha := SettingsCtrls["l_showFill"].Value ? circleAlpha : 0
	mRingAlpha := SettingsCtrls["m_showBorder"].Value ? ringAlpha : 0
	mCircleAlpha := SettingsCtrls["m_showFill"].Value ? circleAlpha : 0
	rRingAlpha := SettingsCtrls["r_showBorder"].Value ? ringAlpha : 0
	rCircleAlpha := SettingsCtrls["r_showFill"].Value ? circleAlpha : 0

	bgLevel := PreviewBgLevel & 0xFF
	bgARGB := 0xFF000000 | (bgLevel << 16) | (bgLevel << 8) | bgLevel
	lineARGB := (bgLevel < 128) ? 0x60FFFFFF : 0x60000000

	if IsObject(PreviewApp) {
		hBmp := BuildPreviewStrip(PREVIEW_APP_W, PREVIEW_APP_H, [
			[defBorder, defBack, defRingAlpha, defCircleAlpha]
		], diameter, thickness, bgARGB, lineARGB, offsetX, offsetY)
		SetPreviewBitmap(PreviewApp, hBmp)
	}

	if IsObject(PreviewColor) {
		hBmp := BuildPreviewStrip(PREVIEW_COLOR_W, PREVIEW_COLOR_H, [
			[defBorder, defBack, defRingAlpha, defCircleAlpha],
			[lBorder, lBack, lRingAlpha, lCircleAlpha],
			[mBorder, mBack, mRingAlpha, mCircleAlpha],
			[rBorder, rBack, rRingAlpha, rCircleAlpha]
		], diameter, thickness, bgARGB, lineARGB, offsetX, offsetY)
		SetPreviewBitmap(PreviewColor, hBmp)
	}
}

SetPreviewBitmap(ctrl, hBmp) {
	if !hBmp
		return
	try ctrl.Value := "HBITMAP:" hBmp
	DllCall("DeleteObject", "Ptr", hBmp)
}

BuildPreviewStrip(canvasW, canvasH, items, diameter, thickness, bgARGB := 0xFF2B2B2B, lineARGB := 0x60FFFFFF,
	offsetX := 0, offsetY := 0) {
	StartGDIPlus()
	bitmap := Gdip_CreateBitmap(canvasW, canvasH)
	if !bitmap
		return 0
	graphics := Gdip_GraphicsFromImage(bitmap)
	Gdip_SetSmoothingMode(graphics, 4)
	Gdip_GraphicsClear(graphics, bgARGB)

	count := items.Length
	slotW := canvasW // count
	cy := canvasH // 2

	for i, item in items {
		borderARGB := item[1], fillARGB := item[2], rA := item[3], cA := item[4]
		trueCx := slotW * (i - 1) + slotW // 2
		trueCy := cy
		ringCx := trueCx + offsetX
		ringCy := trueCy + offsetY

		pLine := Gdip_CreatePen(lineARGB, 1)
		Gdip_DrawLine(graphics, pLine, trueCx - 10, trueCy, trueCx + 10, trueCy)
		Gdip_DrawLine(graphics, pLine, trueCx, trueCy - 10, trueCx, trueCy + 10)
		Gdip_DeletePen(pLine)

		if cA > 0 {
			circleD := Max(diameter - 2 * thickness, 0)
			if circleD > 0 {
				fillColor := ((cA & 0xFF) << 24) | (fillARGB & 0x00FFFFFF)
				pBrush := Gdip_BrushCreateSolid(fillColor)
				Gdip_FillEllipse(graphics, pBrush, ringCx - circleD / 2, ringCy - circleD / 2, circleD, circleD)
				Gdip_DeleteBrush(pBrush)
			}
		}

		if rA > 0 {
			effThickness := Min(thickness, Max(diameter // 2, 1))
			innerSize := Max(diameter - effThickness, 0)
			if innerSize > 0 {
				ringColor := ((rA & 0xFF) << 24) | (borderARGB & 0x00FFFFFF)
				pPen := Gdip_CreatePen(ringColor, effThickness)
				Gdip_DrawEllipse(graphics, pPen, ringCx - innerSize / 2, ringCy - innerSize / 2, innerSize, innerSize)
				Gdip_DeletePen(pPen)
			}
		}
	}

	hBitmap := Gdip_CreateHBITMAPFromBitmap(bitmap, bgARGB)
	Gdip_DisposeImage(bitmap)
	Gdip_DeleteGraphics(graphics)
	return hBitmap
}

HotkeyKeys() {
	static keys := ["toggleHighlight", "moveMousePos", "movePrevMousePos", "saveMousePos", "handlePause",
		"handleRecording", "typeFromClipboard"]
	return keys
}

ConfKeys() {
	static keys := ["diameter", "thickness", "ringTransparency", "circleTransparency", "animTransparency",
		"endTransparency", "steps", "startDiameter", "endDiameter", "animTargetFrameTime",
		"offsetX", "offsetY", "showOnStartup", "showRecordingNotifications", "showMousePosNotifications",
		"syncHotkeysFromOBS"]
	return keys
}

ColorCtrlKeys() {
	static keys := ["default_border", "default_back", "l_border", "l_back", "m_border", "m_back", "r_border", "r_back"]
	return keys
}

ColorFlagKeys() {
	static keys := ["default_showBorder", "default_showFill", "l_showBorder", "l_showFill",
		"m_showBorder", "m_showFill", "r_showBorder", "r_showFill"]
	return keys
}

ProfilesDir() {
	dir := A_ScriptDir "\profiles"
	if !DirExist(dir)
		DirCreate(dir)
	return dir
}

WriteFormToIni(targetIni) {
	global SettingsCtrls

	for key in HotkeyKeys() {
		val := SettingsCtrls[key].Value
		if val != ""
			IniWrite(val, targetIni, "Hotkeys", key)
	}

	for key in ConfKeys() {
		val := SettingsCtrls[key].Value
		if val = ""
			continue
		if key = "animTargetFrameTime" {
			parsed := ""
			try parsed := Float(val)
			if (parsed == "" || parsed < 1 || parsed > 1000)
				val := FormatFrameTime((parsed == "") ? Conf.animTargetFrameTime : Max(1, Min(parsed, 1000)))
		}
		IniWrite(val, targetIni, "Conf", key)
	}

	for ctrlKey in ColorCtrlKeys() {
		clean := CleanHexInput(SettingsCtrls[ctrlKey].Value)
		if clean = ""
			continue
		loop 6 - StrLen(clean)
			clean := "0" clean
		parts := StrSplit(ctrlKey, "_")
		iniKey := ColorIniKey(parts[1], parts[2])
		IniWrite("0xFF" clean, targetIni, "Colors", iniKey)
	}

	for ctrlKey in ColorFlagKeys() {
		parts := StrSplit(ctrlKey, "_")
		iniKey := ColorIniKey(parts[1], parts[2])
		IniWrite(SettingsCtrls[ctrlKey].Value ? "1" : "0", targetIni, "Colors", iniKey)
	}
}

ApplyIniValuesToForm(sourceIni) {
	global SettingsCtrls

	for key in HotkeyKeys() {
		val := IniRead(sourceIni, "Hotkeys", key, SettingsCtrls[key].Value)
		AssignHotkeyValue(key, val)
	}

	for key in ConfKeys() {
		val := IniRead(sourceIni, "Conf", key, SettingsCtrls[key].Value)
		SettingsCtrls[key].Value := val
	}

	for ctrlKey in ColorCtrlKeys() {
		parts := StrSplit(ctrlKey, "_")
		iniKey := ColorIniKey(parts[1], parts[2])
		val := IniRead(sourceIni, "Colors", iniKey, "")
		if val = ""
			continue
		hex6 := ColorToRGBHex(val)
		SettingsCtrls[ctrlKey].Value := hex6
		SetSwatchColor(SettingsCtrls[ctrlKey "_swatch"], hex6)
	}

	for ctrlKey in ColorFlagKeys() {
		parts := StrSplit(ctrlKey, "_")
		iniKey := ColorIniKey(parts[1], parts[2])
		val := IniRead(sourceIni, "Colors", iniKey, "")
		if val != ""
			SettingsCtrls[ctrlKey].Value := val = "1" ? 1 : 0
	}

	UpdateSyncHotkeysState()
	UpdateHotkeyConflictWarning()
	UpdatePreviews()
}

SaveAsProfile() {
	global SettingsGuiObj
	SettingsGuiObj.Opt("+OwnDialogs")

	if CheckHotkeyConflicts().Length > 0 {
		MsgBox("Please resolve conflicting hotkeys before saving a profile.", app.name, "Iconx")
		return
	}

	name := ""
	ib := InputBox("Profile name:", app.name " - Save As", "w300 h120")
	if ib.Result != "OK" || Trim(ib.Value) = ""
		return

	name := RegExReplace(Trim(ib.Value), "[\\/:*?`"<>|]", "_")
	targetIni := ProfilesDir() "\" name ".ini"

	if FileExist(targetIni) {
		if MsgBox("Profile '" name "' already exists. Overwrite?", app.name, "YesNo Icon!") != "Yes"
			return
	}

	WriteFormToIni(targetIni)
	MsgBox("Profile '" name "' saved.", app.name, "Iconi")
}

LoadProfile() {
	global SettingsGuiObj
	SettingsGuiObj.Opt("+OwnDialogs")
	dir := ProfilesDir()
	selected := ""
	try selected := FileSelect(1, dir, "Load Profile", "Settings Profile (*.ini)")
	if selected = ""
		return
	ApplyIniValuesToForm(selected)
	MsgBox("Profile loaded into the form.`nClick Save to apply it, or your changes will be lost if you close this window.", app.name, "Iconi")
}

SaveSettingsGui() {
	global SettingsCtrls, SettingsGuiObj
	SettingsGuiObj.Opt("+OwnDialogs")

	if CheckHotkeyConflicts().Length > 0 {
		MsgBox("Please resolve conflicting hotkeys before saving.", app.name, "Iconx")
		return
	}

	WriteFormToIni(app.iniFile)

	CloseSettingsGui()
	result := MsgBox("Settings saved.`n`nRestart now to apply changes?", app.name, "YesNo Iconi")
	if result = "Yes"
		Reload()
}

