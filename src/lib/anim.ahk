#Requires AutoHotkey v2

CircleCenterDelta(currDiameter) => (Conf.diameter - currDiameter) // 2

AnimateCircle(buttonType, x, y) {
	static activeAnimations := Map()

	if (activeAnimations.Has(buttonType)) {
		try app.animCircles[buttonType].Hide()
		SetTimer(activeAnimations[buttonType].timerFunc, 0)
		activeAnimations.Delete(buttonType)
	}

	if (!buttonType || !colors.Has(buttonType))
		return

	if (!colors[buttonType].showFill)
		return

	steps := Max(Conf.steps, 1)
	animStep := 1
	lastTime := A_TickCount
	circle := app.animCircles[buttonType]

	initialDelta := CircleCenterDelta(Conf.startDiameter)
	try {
		circle.Update(Conf.startDiameter, Conf.startTransparency)
		circle.Show(x + Conf.offsetFinalX + initialDelta, y + Conf.offsetFinalY + initialDelta)
	}

	animationTimer() {
		currTime := A_TickCount

		if (currTime - lastTime < Conf.animTargetFrameTime && animStep > 1)
			return

		if (animStep > steps) {
			try circle.Hide()
			SetTimer(animationTimer, 0)
			activeAnimations.Delete(buttonType)
			return
		}

		progress := animStep / steps
		easedProgress := progress * progress

		currDiameter := Floor(Conf.startDiameter + easedProgress * (Conf.endDiameter - Conf.startDiameter))
		currDiameter := Max(currDiameter, 1)
		currDelta := CircleCenterDelta(currDiameter)

		fadeStartStep := steps * 0.75
		fadeRangeSteps := steps * 0.25
		if (animStep > fadeStartStep) {
			fadeProgress := (animStep - fadeStartStep) / fadeRangeSteps
			currTransparency := Round(Conf.startTransparency - fadeProgress * (Conf.startTransparency - Conf.endTransparency))
			currTransparency := Max(currTransparency, Conf.endTransparency)
		} else {
			currTransparency := Conf.startTransparency
		}

		try {
			circle.Update(currDiameter, currTransparency)
			circle.Show(x + Conf.offsetFinalX + currDelta, y + Conf.offsetFinalY + currDelta)
		}

		lastTime := currTime
		animStep++
	}

	activeAnimations[buttonType] := { timerFunc: animationTimer }

	animationTimer()
	SetTimer(animationTimer, Max(Conf.animTargetFrameTime, 1))
}