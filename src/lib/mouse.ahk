#Requires AutoHotkey v2

saveMousePos() {
	global x, y
	MouseGetPos(&x, &y)
	State.mousePosHistory.Push([x, y])
	if (State.mousePosHistory.Length > State.mousePosLength) {
		State.mousePosHistory.RemoveAt(1)
	}
	State.prevPosIndex := State.mousePosHistory.Length
	ShowMessage("Position saved!`n(" . State.mousePosHistory.Length . ")", "0b60a5", "ffffff", 175, 1500)
}

moveMousePos() {
	global x, y
	if (State.mousePosHistory.Length > 0) {
		pos := State.mousePosHistory[State.mousePosHistory.Length]
		x := pos[1]
		y := pos[2]
		MouseMove(x, y, 5)
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
	ShowMessage("Position: (" . State.prevPosIndex . ")", "a7b900", "ffffff", 200, 1200)
	newIdx := Mod(State.prevPosIndex - 1, State.mousePosHistory.Length)
	State.prevPosIndex := newIdx ? newIdx : State.mousePosHistory.Length
}

HandleButtonUp(currentCircle, params, mouseX, mouseY) {
	HideRingsOnly()
	HideCirclesOnly()
	if (currentCircle != "default" && State.hl) {
		capturedCircle := currentCircle
		capturedX := mouseX
		capturedY := mouseY
		SetTimer(() => AnimateCircle(capturedCircle, capturedX, capturedY), -1)
	}
	app.rings["default"].Show(params*)
	return "default"
}

HandleButtonDown(wParam, currentCircle, params) {
	switch wParam {
		case 0x201: currentCircle := "l"
		case 0x204: currentCircle := "r"
		case 0x207: currentCircle := "m"
		default: currentCircle := "default"
	}
	HideRingsOnly()
	HideCirclesOnly()
	if (currentCircle != "default" && State.hl) {
		ShowAtomic([
			[app.rings[currentCircle], params[1], params[2]],
			[app.circles[currentCircle], params[1] + Conf.circlePositionOffset, params[2] + Conf.circlePositionOffset]
		])
	}
	return currentCircle
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
			params := [mouseX + Conf.offset, mouseY + Conf.offset]
			currentCircle := HandleButtonDown(wParam, currentCircle, params)
			RenderState.circle := currentCircle
			RenderState.x := mouseX
			RenderState.y := mouseY
			RenderState.dirty := true
		case 0x202, 0x208, 0x205:
			params := [mouseX + Conf.offset, mouseY + Conf.offset]
			capturedCircle := currentCircle
			SetTimer(() => HandleButtonUp(capturedCircle, params, mouseX, mouseY), -1)
			currentCircle := "default"
			RenderState.circle := "default"
			RenderState.dirty := true
	}

	return DllCall_CallNextHookEx(nCode, wParam, lParam)
}

RenderLoop() {
	static lastShownCircle := "default"
	static lastParams := [0, 0]

	if !RenderState.dirty
		return

	params := [RenderState.x + Conf.offset, RenderState.y + Conf.offset]
	circleToShow := RenderState.circle

	if (lastParams[1] != params[1] || lastParams[2] != params[2] || lastShownCircle != circleToShow) {
		if (lastShownCircle != circleToShow) {
			app.rings[lastShownCircle].Hide()
			HideCirclesOnly()
		}
		if (circleToShow != "default") {
			ShowAtomic([
				[app.rings[circleToShow], params[1], params[2]],
				[app.circles[circleToShow], params[1] + Conf.circlePositionOffset, params[2] + Conf.circlePositionOffset]
			])
		} else {
			app.rings[circleToShow].Show(params*)
		}
		lastShownCircle := circleToShow
		lastParams := params.Clone()
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
	global x, y
	if State.Hook {
		State.Hook.__Delete()
		State.Hook := ""
		SetTimer(RenderLoop, 0)
	}
	HideAllGraphics()
	if !show || !State.hl
		return
	MouseGetPos(&x, &y)
	State.Hook := WindowsHook(14, LowLevelMouseProc)
	RenderState.x := x
	RenderState.y := y
	RenderState.circle := "default"
	RenderState.dirty := false
	SetTimer(RenderLoop, 8)
	app.rings["default"].Show(x + Conf.offset, y + Conf.offset)
	State.lastUpdate := A_TickCount
}