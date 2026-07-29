#Requires AutoHotkey v2

AnimateCircle(buttonType, x, y) {
  static activeAnimations := Map()

  if (activeAnimations.Has(buttonType)) {
    try app.animCircles[buttonType].Hide()
    SetTimer(activeAnimations[buttonType].timerFunc, 0)
    activeAnimations.Delete(buttonType)
  }

  if (!buttonType || !colors.Has(buttonType))
    return

  animStep := 1
  circle := app.animCircles[buttonType]

  initialOffset := Conf.offset + (Conf.diameter - Conf.startDiameter) // 2
  circle.Update(Conf.startDiameter, Conf.startTransparency)
  circle.Show(x + initialOffset, y + initialOffset)

  animationTimer() {
    static lastTime := A_TickCount
    currTime := A_TickCount

    if (currTime - lastTime < Conf.animTargetFrameTime && animStep > 1)
      return

    if (animStep > Conf.steps) {
      try circle.Hide()
      SetTimer(animationTimer, 0)
      activeAnimations.Delete(buttonType)
      return
    }

    progress := animStep / Conf.steps
    easedProgress := progress * progress

    currDiameter := Floor(Conf.startDiameter + easedProgress * (Conf.endDiameter - Conf.startDiameter))
    currDiameter := Max(currDiameter, 1)
    currOffset := Conf.offset + (Conf.diameter - currDiameter) // 2

    if (animStep > Conf.steps * 0.75) {
      fadeProgress := (animStep - Conf.steps * 0.75) / (Conf.steps * 0.25)
      currTransparency := Round(Conf.startTransparency - fadeProgress * (Conf.startTransparency - Conf.endTransparency))
      currTransparency := Max(currTransparency, Conf.endTransparency)
    } else {
      currTransparency := Conf.startTransparency
    }

    try {
      circle.Update(currDiameter, currTransparency)
      circle.Show(x + currOffset, y + currOffset)
    }

    lastTime := currTime
    animStep++
  }

  activeAnimations[buttonType] := { timerFunc: animationTimer }

  animationTimer()
  SetTimer(animationTimer, 10)
}
