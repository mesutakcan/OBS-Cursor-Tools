#Requires AutoHotkey v2

global gdiplusToken := 0

StartGDIPlus() {
	global gdiplusToken
	if (!gdiplusToken) {
		gdiplusToken := Gdip_Startup()
		if (!gdiplusToken) {
			throw Error("Failed to initialize GDI+!")
		}
	}
	return gdiplusToken
}

ShutdownGDIPlus() {
	global gdiplusToken
	if (gdiplusToken) {
		Gdip_Shutdown(gdiplusToken)
		gdiplusToken := 0
	}
}

CreateHBITMAPWithAlpha(bitmap) {
	hBitmap := Gdip_CreateARGBHBITMAPFromBitmap(&bitmap)
	if (!hBitmap) {
		throw Error("Failed to create HBITMAP!")
	}
	return hBitmap
}

class WindowsHook {
	__New(type, callback, isGlobal := true) {
		this.pCallback := CallbackCreate(callback, 'Fast', 3)
		this.hHook := DllCall('SetWindowsHookEx', 'Int', type, 'Ptr', this.pCallback
			, 'Ptr', !isGlobal ? 0 : DllCall('GetModuleHandle', 'UInt', 0, 'Ptr')
			, 'UInt', isGlobal ? 0 : DllCall('GetCurrentThreadId'), 'Ptr')
		if (!this.hHook) {
			throw Error("Failed to create Windows Hook!")
		}
	}
	Unhook() {
		if (this.hHook) {
			DllCall('UnhookWindowsHookEx', 'Ptr', this.hHook)
			this.hHook := 0
		}
		if (this.pCallback) {
			CallbackFree(this.pCallback)
			this.pCallback := 0
		}
	}
	__Delete() => this.Unhook()
}

CreateLayeredWindow(hBitmap, onTop := true) {
	static exStyles := (WS_EX_LAYERED := 0x00080000) | (WS_EX_TRANSPARENT := 0x00000020), ULW_ALPHA := 0x2
	BITMAP := Buffer(16 + A_PtrSize * 2, 0)
	if (!DllCall('GetObject', 'Ptr', hBitmap, 'Int', BITMAP.size, 'Ptr', BITMAP)) {
		throw Error("Failed to retrieve bitmap info!")
	}
	w := NumGet(BITMAP, 4, 'UInt'), h := NumGet(BITMAP, 8, 'UInt')
	hDC := DllCall('CreateCompatibleDC', 'Ptr', 0, 'Ptr')
	if (!hDC) {
		throw Error("Failed to create DC!")
	}
	hObj := DllCall('SelectObject', 'Ptr', hDC, 'Ptr', hBitmap, 'Ptr')
	if (!hObj) {
		DllCall('DeleteDC', 'Ptr', hDC)
		throw Error("Failed to select Bitmap!")
	}
	wnd := Gui('-DpiScale -Caption Owner E' . exStyles . (onTop ? ' AlwaysOnTop' : ''))
	wnd.Show('Hide')
	DllCall('UpdateLayeredWindow', 'Ptr', wnd.hwnd, 'Ptr', 0, 'Ptr', 0, 'Int64P', w | h << 32,
		'Ptr', hDC, 'Int64P', 0, 'UInt', 0, 'UIntP', 255 << 16 | 1 << 24, 'UInt', ULW_ALPHA)
	DllCall('SelectObject', 'Ptr', hDC, 'Ptr', hObj, 'Ptr')
	DllCall('DeleteDC', 'Ptr', hDC)
	return wnd
}

UpdateLayeredWindowBitmap(hwnd, hBitmap) {
	static ULW_ALPHA := 0x2
	BITMAP := Buffer(16 + A_PtrSize * 2, 0)
	if (!DllCall('GetObject', 'Ptr', hBitmap, 'Int', BITMAP.size, 'Ptr', BITMAP)) {
		return
	}
	w := NumGet(BITMAP, 4, 'UInt'), h := NumGet(BITMAP, 8, 'UInt')
	hDC := DllCall('CreateCompatibleDC', 'Ptr', 0, 'Ptr')
	hObj := DllCall('SelectObject', 'Ptr', hDC, 'Ptr', hBitmap, 'Ptr')
	DllCall('UpdateLayeredWindow', 'Ptr', hwnd, 'Ptr', 0, 'Ptr', 0, 'Int64P', w | h << 32,
		'Ptr', hDC, 'Int64P', 0, 'UInt', 0, 'UIntP', 255 << 16 | 1 << 24, 'UInt', ULW_ALPHA)
	DllCall('SelectObject', 'Ptr', hDC, 'Ptr', hObj, 'Ptr')
	DllCall('DeleteDC', 'Ptr', hDC)
}

EvictCache(cache) {
	evictCount := Max(1, cache.Count // 4)
	keysToEvict := []
	for key, hBitmap in cache {
		keysToEvict.Push(key)
		if (keysToEvict.Length >= evictCount)
			break
	}
	for key in keysToEvict {
		DllCall("DeleteObject", "Ptr", cache[key])
		cache.Delete(key)
	}
}

class Ring {
	static hBitmapCache := Map()
	static maxCacheSize := 200

	static _BuildBitmap(diameter, thickness, colorARGB, transparency) {
		StartGDIPlus()
		margin := Conf.ringMargin
		size := Max(diameter + 2 * margin, 1)
		bitmap := Gdip_CreateBitmap(size, size)
		if (!bitmap)
			throw Error("Failed to create Bitmap!")
		graphics := Gdip_GraphicsFromImage(bitmap)
		if (!graphics) {
			Gdip_DisposeImage(bitmap)
			throw Error("Failed to create Graphics!")
		}
		Gdip_SetSmoothingMode(graphics, 4)
		Gdip_GraphicsClear(graphics, 0x00000000)
		adjustedColor := (transparency << 24) | (colorARGB & 0x00FFFFFF)
		effectiveThickness := Min(thickness, Max(diameter // 2, 1))
		pPen := Gdip_CreatePen(adjustedColor, effectiveThickness)
		if (!pPen) {
			Gdip_DeleteGraphics(graphics)
			Gdip_DisposeImage(bitmap)
			throw Error("Failed to create Pen!")
		}
		innerSize := Max(diameter - effectiveThickness, 0)
		inset := margin + effectiveThickness / 2
		if (innerSize > 0)
			Gdip_DrawEllipse(graphics, pPen, inset, inset, innerSize, innerSize)
		hBitmap := CreateHBITMAPWithAlpha(bitmap)
		if (!hBitmap) {
			Gdip_DeletePen(pPen)
			Gdip_DeleteGraphics(graphics)
			Gdip_DisposeImage(bitmap)
			throw Error("Failed to create HBITMAP!")
		}
		Gdip_DeletePen(pPen)
		Gdip_DisposeImage(bitmap)
		Gdip_DeleteGraphics(graphics)
		return hBitmap
	}

	_GetOrBuildBitmap(diameter, thickness, colorARGB, transparency) {
		cacheKey := diameter "," thickness "," colorARGB "," transparency
		if !Ring.hBitmapCache.Has(cacheKey) {
			if (Ring.hBitmapCache.Count >= Ring.maxCacheSize)
				EvictCache(Ring.hBitmapCache)
			Ring.hBitmapCache[cacheKey] := Ring._BuildBitmap(diameter, thickness, colorARGB, transparency)
		}
		this.hBitmap := Ring.hBitmapCache[cacheKey]
	}

	__New(diameter, thickness, colorARGB, transparency := 255) {
		this.diameter := diameter
		this.thickness := thickness
		this.colorARGB := colorARGB
		this.transparency := transparency
		this._GetOrBuildBitmap(diameter, thickness, colorARGB, transparency)
		this.gui := CreateLayeredWindow(this.hBitmap)
	}

	Update(diameter, thickness, colorARGB, transparency) {
		this.diameter := diameter
		this.thickness := thickness
		this.colorARGB := colorARGB
		this.transparency := transparency
		this.UpdateBitmap()
		UpdateLayeredWindowBitmap(this.gui.hwnd, this.hBitmap)
	}

	UpdateBitmap() {
		this._GetOrBuildBitmap(this.diameter, this.thickness, this.colorARGB, this.transparency)
	}

	Show(x, y) => this.gui.Show('NA x' . x . ' y' . y)
	Hide() => this.gui.Hide()
	__Delete() => this.gui.Destroy()
}

class SolidCircle {
	static hBitmapCache := Map()
	static maxCacheSize := 200

	static _BuildBitmap(diameter, colorARGB, transparency) {
		StartGDIPlus()
		margin := Conf.ringMargin
		size := Max(diameter + 2 * margin, 1)
		bitmap := Gdip_CreateBitmap(size, size)
		if (!bitmap) {
			throw Error("Failed to create Bitmap!")
		}
		graphics := Gdip_GraphicsFromImage(bitmap)
		if (!graphics) {
			Gdip_DisposeImage(bitmap)
			throw Error("Failed to create Graphics!")
		}
		Gdip_SetSmoothingMode(graphics, 4)
		Gdip_GraphicsClear(graphics, 0x00000000)
		adjustedARGB := (transparency << 24) | (colorARGB & 0x00FFFFFF)
		pBrush := Gdip_BrushCreateSolid(adjustedARGB)
		if (!pBrush) {
			Gdip_DeleteGraphics(graphics)
			Gdip_DisposeImage(bitmap)
			throw Error("Failed to create Brush!")
		}
		if (diameter > 0)
			Gdip_FillEllipse(graphics, pBrush, margin, margin, diameter, diameter)
		hBitmap := CreateHBITMAPWithAlpha(bitmap)
		if (!hBitmap) {
			Gdip_DeleteBrush(pBrush)
			Gdip_DeleteGraphics(graphics)
			Gdip_DisposeImage(bitmap)
			throw Error("Failed to create HBITMAP!")
		}
		Gdip_DeleteBrush(pBrush)
		Gdip_DisposeImage(bitmap)
		Gdip_DeleteGraphics(graphics)
		return hBitmap
	}

	_GetOrBuildBitmap(diameter, colorARGB, transparency) {
		cacheKey := diameter "," colorARGB "," transparency
		if !SolidCircle.hBitmapCache.Has(cacheKey) {
			if (SolidCircle.hBitmapCache.Count >= SolidCircle.maxCacheSize)
				EvictCache(SolidCircle.hBitmapCache)
			SolidCircle.hBitmapCache[cacheKey] := SolidCircle._BuildBitmap(diameter, colorARGB, transparency)
		}
		this.hBitmap := SolidCircle.hBitmapCache[cacheKey]
	}

	__New(diameter, colorARGB, transparency := 255) {
		this.diameter := diameter
		this.colorARGB := colorARGB
		this.transparency := transparency
		this._GetOrBuildBitmap(diameter, colorARGB, transparency)
		this.gui := CreateLayeredWindow(this.hBitmap)
	}

	Update(diameter, transparency) {
		this.diameter := diameter
		this.transparency := transparency
		this._GetOrBuildBitmap(diameter, this.colorARGB, transparency)
		UpdateLayeredWindowBitmap(this.gui.hwnd, this.hBitmap)
	}

	Show(x, y) => this.gui.Show('NA x' . x . ' y' . y)
	Hide() => this.gui.Hide()
	__Delete() => this.gui.Destroy()
}

HideAllGraphics() {
	HideRingsOnly()
	HideCirclesOnly()
}

ShowAtomic(items) {
	static SWP_NOSIZE := 0x0001, SWP_NOZORDER := 0x0004, SWP_NOACTIVATE := 0x0010, SWP_SHOWWINDOW := 0x0040
	hdwp := DllCall("BeginDeferWindowPos", "Int", items.Length, "Ptr")
	if !hdwp
		return
	for item in items {
		hdwp := DllCall("DeferWindowPos", "Ptr", hdwp, "Ptr", item[1].gui.hwnd, "Ptr", 0,
			"Int", item[2], "Int", item[3], "Int", 0, "Int", 0,
			"UInt", SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_SHOWWINDOW, "Ptr")
		if !hdwp
			return
	}
	DllCall("EndDeferWindowPos", "Ptr", hdwp)
}

HideRingsOnly() {
	for key, ringObj in app.rings
		ringObj.Hide()
}

HideCirclesOnly() {
	for key, circleObj in app.circles
		circleObj.Hide()
}

InitGraphics() {
	for k, v in colors {
		ringAlpha := v.showBorder ? Conf.ringTransparency : 0
		app.rings[k] := Ring(Conf.diameter, Conf.thickness, v.border, ringAlpha)
	}
	for k, v in colors {
		circleAlpha := v.showFill ? Conf.circleTransparency : 0
		app.circles[k] := SolidCircle(Conf.circleDiameter, v.back, circleAlpha)
		if (k != "default")
			app.animCircles[k] := SolidCircle(Conf.startDiameter, v.back, Conf.startTransparency)
	}
}

CleanupResources(*) {
	HideAllGraphics()
	if State.Hook {
		State.Hook.Unhook()
		State.Hook := ""
	}
	for key, hBitmap in Ring.hBitmapCache {
		DllCall("DeleteObject", "Ptr", hBitmap)
	}
	Ring.hBitmapCache.Clear()
	for key, hBitmap in SolidCircle.hBitmapCache {
		DllCall("DeleteObject", "Ptr", hBitmap)
	}
	SolidCircle.hBitmapCache.Clear()
	ShutdownGDIPlus()
}