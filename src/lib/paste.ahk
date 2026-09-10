#Requires AutoHotkey v2

typeFromClipboard() {
	if (!A_Clipboard)
		return

	clipText := StrReplace(A_Clipboard, "  ", "`t")
	lines := StrSplit(clipText, "`n")
	prevTabCount := 0

	for line in lines {
		if GetKeyState("Esc", "P")
			return

		content := LTrim(line, "`t")
		tabCount := StrLen(line) - StrLen(content)

		diff := tabCount - prevTabCount
		if (diff > 0) {
			Send("{Tab " diff "}")
		} else if (diff < 0) {
			Send("{Backspace " Abs(diff) "}")
		}

		if (content != "") {
			Send("{Text}" content)
		}

		prevTabCount := tabCount
	}
}