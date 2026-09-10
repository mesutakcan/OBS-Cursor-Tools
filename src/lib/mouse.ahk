#Requires AutoHotkey v2

saveMousePos(notify := true) {
	MouseGetPos(&posX, &posY)
	State.mousePosHistory.Push([posX, posY])
	if (State.mousePosHistory.Length > State.mousePosLength) {
		State.mousePosHistory.RemoveAt(1)
	}
	State.prevPosIndex := State.mousePosHistory.Length
	if notify && Conf.showMousePosNotifications
		ShowMessage("Position saved!`n(" . State.mousePosHistory.Length . ")", "0b60a5", "ffffff", 175, 1500)
}

moveMousePos() {
	if (State.mousePosHistory.Length > 0) {
		pos := State.mousePosHistory[State.mousePosHistory.Length]
		MouseMove(pos[1], pos[2], 5)
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
	MouseMove(pos[1], pos[2], 5)
	if Conf.showMousePosNotifications
		ShowMessage("Position: (" . State.prevPosIndex . ")", "a7b900", "ffffff", 200, 1200)
	newIdx := Mod(State.prevPosIndex - 1, State.mousePosHistory.Length)
	State.prevPosIndex := newIdx ? newIdx : State.mousePosHistory.Length
}

HandleButtonUp(currentCircle, mouseX, mouseY) {
	if (currentCircle != "default" && State.hl) {
		capturedCircle := currentCircle
		capturedX := mouseX
		capturedY := mouseY
		SetTimer(() => AnimateCircle(capturedCircle, capturedX, capturedY), -1)
	}
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
			RenderState.dirty := true
		case 0x201, 0x207, 0x204:
			currentCircle := CircleForButton(wParam)
			RenderState.circle := currentCircle
			RenderState.x := mouseX
			RenderState.y := mouseY
			RenderState.dirty := true
		case 0x202, 0x208, 0x205:
			capturedCircle := currentCircle
			SetTimer(() => HandleButtonUp(capturedCircle, mouseX, mouseY), -1)
			currentCircle := "default"
			RenderState.circle := "default"
			RenderState.dirty := true
	}

	return DllCall_CallNextHookEx(nCode, wParam, lParam)
}

RenderLoop() {
	static lastShownCircle := "default"
	static lastX := -9999
	static lastY := -9999

	if !RenderState.dirty
		return

	curX := RenderState.x + Conf.offsetFinalX
	curY := RenderState.y + Conf.offsetFinalY
	circleToShow := RenderState.circle

	if (lastX != curX || lastY != curY || lastShownCircle != circleToShow) {
		if (lastShownCircle != circleToShow) {
			app.rings[lastShownCircle].Hide()
			HideCirclesOnly()
		}
		ShowAtomic([
			[app.rings[circleToShow], curX, curY],
			[app.circles[circleToShow], curX + Conf.circlePositionOffset, curY + Conf.circlePositionOffset]
		])
		lastShownCircle := circleToShow
		lastX := curX
		lastY := curY
	}

	RenderState.dirty := false
}

ToggleHighlight() {
	State.hl := !State.hl
	State.toggle_used := true
	showHighlight(State.hl)
	UpdateTrayMenu()
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
	SetTimer(RenderLoop, 8)
	ShowAtomic([
		[app.rings["default"], curX + Conf.offsetFinalX, curY + Conf.offsetFinalY],
		[app.circles["default"], curX + Conf.offsetFinalX + Conf.circlePositionOffset, curY + Conf.offsetFinalY + Conf.circlePositionOffset]
	])
}