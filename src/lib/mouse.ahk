#Requires AutoHotkey v2

saveMousePos(notify := true) {
	MouseGetPos(&posX, &posY)
	State.mousePosHistory.Push([posX, posY])
	if (State.mousePosHistory.Length > State.mousePosLength) {
		State.mousePosHistory.RemoveAt(1)
	}
	State.prevPosIndex := Max(0, State.mousePosHistory.Length - 1)
	if notify && Conf.showMousePosNotifications
		ShowMessage("Position saved!`n(" . State.mousePosHistory.Length . ")", "0b60a5", "ffffff", 175, 1500)
}

GlideMouse(toX, toY) {
	static gen := 0
	myGen := ++gen
	MouseGetPos(&fromX, &fromY)
	dx := toX - fromX
	dy := toY - fromY
	steps := Max(1, Ceil(Sqrt(dx * dx + dy * dy) / 60))
	loop steps {
		if (myGen != gen)
			return
		progress := A_Index / steps
		MouseMove(Round(fromX + dx * progress), Round(fromY + dy * progress), 0)
		if (A_Index < steps)
			Sleep(10)
	}
}

moveMousePos() {
	if (State.mousePosHistory.Length > 0) {
		pos := State.mousePosHistory[State.mousePosHistory.Length]
		GlideMouse(pos[1], pos[2])
		State.prevPosIndex := Max(0, State.mousePosHistory.Length - 1)
	}
}

movePrevMousePos() {
	if (State.mousePosHistory.Length = 0) {
		return
	}
	if (State.prevPosIndex = 0) {
		State.prevPosIndex := Max(1, State.mousePosHistory.Length - 1)
	}
	pos := State.mousePosHistory[State.prevPosIndex]
	GlideMouse(pos[1], pos[2])
	if Conf.showMousePosNotifications
		ShowMessage("Position: (" . State.prevPosIndex . ")", "a7b900", "ffffff", 200, 1200)
	newIdx := Mod(State.prevPosIndex - 1, State.mousePosHistory.Length)
	State.prevPosIndex := newIdx ? newIdx : State.mousePosHistory.Length
}

HandleButtonUp(currentCircle, mouseX, mouseY) {
	if (currentCircle != "default" && State.hl)
		AnimateCircle(currentCircle, mouseX, mouseY)
}

CircleForButton(wParam) {
	switch wParam {
		case 0x201: return "l"
		case 0x204: return "r"
		case 0x207: return "m"
		default: return "default"
	}
}

global RenderState := { x: 0, y: 0, circle: "default", dirty: false }

LowLevelMouseProc(nCode, wParam, lParam) {
	static currentCircle := "default"

	if (nCode < 0 || !State.hl) {
		return DllCall_CallNextHookEx(nCode, wParam, lParam)
	}

	mouseX := NumGet(lParam, 0, 'Int')
	mouseY := NumGet(lParam, 4, 'Int')

	switch wParam {
		case 0x200:
			RenderState.x := mouseX
			RenderState.y := mouseY
			MarkRenderDirty()
		case 0x201, 0x207, 0x204:
			currentCircle := CircleForButton(wParam)
			RenderState.circle := currentCircle
			RenderState.x := mouseX
			RenderState.y := mouseY
			MarkRenderDirty()
		case 0x202, 0x208, 0x205:
			capturedCircle := currentCircle
			SetTimer(() => HandleButtonUp(capturedCircle, mouseX, mouseY), -1)
			currentCircle := "default"
			RenderState.circle := "default"
			MarkRenderDirty()
	}

	return DllCall_CallNextHookEx(nCode, wParam, lParam)
}

MarkRenderDirty() {
	if !RenderState.dirty
		SetTimer(RenderLoop, -8)
	RenderState.dirty := true
}

ShowState(circleKey, x, y) {
	items := []
	if colors[circleKey].showBorder
		items.Push([app.rings[circleKey], x, y])
	if colors[circleKey].showFill
		items.Push([app.circles[circleKey], x + Conf.circlePositionOffset, y + Conf.circlePositionOffset])
	if items.Length
		ShowAtomic(items)
}

RenderLoop() {
	static lastShownCircle := "default"
	static lastX := -9999
	static lastY := -9999

	if !RenderState.dirty
		return
	RenderState.dirty := false

	curX := RenderState.x + Conf.offsetFinalX
	curY := RenderState.y + Conf.offsetFinalY
	circleToShow := RenderState.circle

	if (lastX != curX || lastY != curY || lastShownCircle != circleToShow) {
		if (lastShownCircle != circleToShow) {
			app.rings[lastShownCircle].Hide()
			HideCirclesOnly()
		}
		ShowState(circleToShow, curX, curY)
		lastShownCircle := circleToShow
		lastX := curX
		lastY := curY
	}
}

HighlightWanted() {
	if State.programPaused || IsObject(SettingsGuiObj)
		return false
	if (State.hlOverride >= 0)
		return State.hlOverride = 1
	return State.alwaysShow || (State.recording && !State.paused)
}

RefreshHighlight() {
	State.hl := HighlightWanted()
	showHighlight(State.hl)
	UpdateTrayMenu()
}

ToggleHighlight() {
	if State.programPaused || IsObject(SettingsGuiObj)
		return
	State.hlOverride := State.hl ? 0 : 1
	RefreshHighlight()
}

showHighlight(show := true) {
	if State.Hook {
		State.Hook.Unhook()
		State.Hook := ""
		SetTimer(RenderLoop, 0)
	}
	HideAllGraphics()
	if !show || !State.hl
		return
	MouseGetPos(&curX, &curY)
	State.Hook := WindowsHook(14, LowLevelMouseProc)
	RenderState.x := curX
	RenderState.y := curY
	RenderState.circle := "default"
	RenderState.dirty := false
	ShowState("default", curX + Conf.offsetFinalX, curY + Conf.offsetFinalY)
}