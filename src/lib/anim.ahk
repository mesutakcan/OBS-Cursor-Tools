#Requires AutoHotkey v2

CircleCenterDelta(currDiameter) => (Conf.diameter - currDiameter) // 2

AnimFrameParams(animStep, steps) {
	progress := animStep / steps
	easedProgress := progress * progress
	currDiameter := Max(Floor(Conf.startDiameter + easedProgress * (Conf.endDiameter - Conf.startDiameter)), 1)

	fadeStartStep := steps * 0.75
	fadeRangeSteps := steps * 0.25
	if (animStep > fadeStartStep) {
		fadeProgress := (animStep - fadeStartStep) / fadeRangeSteps
		currTransparency := Round(Conf.startTransparency - fadeProgress * (Conf.startTransparency - Conf.endTransparency))
		currTransparency := Max(currTransparency, Conf.endTransparency)
	} else {
		currTransparency := Conf.startTransparency
	}
	return [currDiameter, currTransparency]
}

PrewarmAnimCache() {
	steps := Max(Conf.steps, 1)
	targets := []
	for key, circle in app.animCircles {
		if colors[key].showFill
			targets.Push(circle)
	}
	if (targets.Length * (steps + 1) + app.circles.Count > SolidCircle.maxCacheSize)
		return
	for circle in targets {
		circle.Warm(Conf.startDiameter, Conf.startTransparency)
		loop steps {
			frame := AnimFrameParams(A_Index, steps)
			circle.Warm(frame[1], frame[2])
		}
	}
}

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
		ShowAtomic([[circle, x + Conf.offsetFinalX + initialDelta, y + Conf.offsetFinalY + initialDelta]])
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

		frame := AnimFrameParams(animStep, steps)
		currDelta := CircleCenterDelta(frame[1])

		try {
			circle.Update(frame[1], frame[2])
			circle.Show(x + Conf.offsetFinalX + currDelta, y + Conf.offsetFinalY + currDelta)
		}

		lastTime := currTime
		animStep++
	}

	activeAnimations[buttonType] := { timerFunc: animationTimer }

	animationTimer()
	SetTimer(animationTimer, Max(Conf.animTargetFrameTime, 1))
}