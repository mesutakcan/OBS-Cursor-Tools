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
	DllCall("gdiplus\GdipGetImageWidth", "Ptr", bitmap, "UInt*", &width := 0)
	DllCall("gdiplus\GdipGetImageHeight", "Ptr", bitmap, "UInt*", &height := 0)

	hDC := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
	bi := Buffer(40, 0)
	NumPut("UInt", 40, bi, 0)
	NumPut("Int", width, bi, 4)
	NumPut("Int", -height, bi, 8)
	NumPut("UShort", 1, bi, 12)
	NumPut("UShort", 32, bi, 14)
	NumPut("UInt", 0, bi, 16)

	hBitmap := DllCall("CreateDIBSection", "Ptr", hDC, "Ptr", bi, "UInt", 0, "Ptr*", &ppvBits := 0, "Ptr", 0, "UInt", 0,
		"Ptr")
	if (!hBitmap) {
		DllCall("DeleteDC", "Ptr", hDC)
		throw Error("Failed to create DIB Section!")
	}

	hObj := DllCall("SelectObject", "Ptr", hDC, "Ptr", hBitmap, "Ptr")
	graphics := Gdip_GraphicsFromHDC(hDC)
	if (!graphics) {
		DllCall("SelectObject", "Ptr", hDC, "Ptr", hObj)
		DllCall("DeleteDC", "Ptr", hDC)
		throw Error("Failed to create Graphics!")
	}
	Gdip_SetSmoothingMode(graphics, 4)
	DllCall("gdiplus\GdipDrawImageRect", "Ptr", graphics, "Ptr", bitmap, "Float", 0, "Float", 0, "Float", width,
		"Float", height)
	Gdip_DeleteGraphics(graphics)
	DllCall("SelectObject", "Ptr", hDC, "Ptr", hObj)
	DllCall("DeleteDC", "Ptr", hDC)

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
	__Delete() {
		if (this.hHook) {
			DllCall('UnhookWindowsHookEx', 'Ptr', this.hHook)
			this.hHook := 0
		}
		if (this.pCallback) {
			CallbackFree(this.pCallback)
			this.pCallback := 0
		}
	}
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
	for key, hBitmap in cache {
		DllCall("DeleteObject", "Ptr", hBitmap)
		cache.Delete(key)
		break
	}
}

class Ring {
	static hBitmapCache := Map()
	static maxCacheSize := 200

	static _BuildBitmap(diameter, thickness, colorARGB, transparency) {
		StartGDIPlus()
		padding := 3
		bitmap := Gdip_CreateBitmap(diameter + 2 * padding, diameter + 2 * padding)
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
		pPen := Gdip_CreatePen(adjustedColor, thickness)
		if (!pPen) {
			Gdip_DeleteGraphics(graphics)
			Gdip_DisposeImage(bitmap)
			throw Error("Failed to create Pen!")
		}
		Gdip_DrawEllipse(graphics, pPen, padding, padding, diameter, diameter)
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
		this.cacheKey := cacheKey
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
	__New(diameter, colorARGB, transparency := 255) {
		this.diameter := diameter
		this.colorARGB := colorARGB
		this.transparency := transparency

		this.UpdateBitmap()
		this.gui := CreateLayeredWindow(this.hBitmap)
	}

	UpdateBitmap() {
		StartGDIPlus()
		padding := 3
		bitmap := Gdip_CreateBitmap(this.diameter + 2 * padding, this.diameter + 2 * padding)
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
		adjustedARGB := (this.transparency << 24) | (this.colorARGB & 0x00FFFFFF)
		pBrush := Gdip_BrushCreateSolid(adjustedARGB)
		if (!pBrush) {
			Gdip_DeleteGraphics(graphics)
			Gdip_DisposeImage(bitmap)
			throw Error("Failed to create Brush!")
		}
		Gdip_FillEllipse(graphics, pBrush, padding, padding, this.diameter, this.diameter)
		this.hBitmap := CreateHBITMAPWithAlpha(bitmap)
		if (!this.hBitmap) {
			Gdip_DeleteBrush(pBrush)
			Gdip_DeleteGraphics(graphics)
			Gdip_DisposeImage(bitmap)
			throw Error("Failed to create HBITMAP!")
		}
		Gdip_DeleteBrush(pBrush)
		Gdip_DisposeImage(bitmap)
		Gdip_DeleteGraphics(graphics)
	}

	Update(diameter, transparency) {
		this.diameter := diameter
		this.transparency := transparency
		oldBitmap := this.hBitmap
		this.UpdateBitmap()
		UpdateLayeredWindowBitmap(this.gui.hwnd, this.hBitmap)
		if (oldBitmap && oldBitmap != this.hBitmap) {
			DllCall("DeleteObject", "Ptr", oldBitmap)
		}
	}

	Show(x, y) => this.gui.Show('NA x' . x . ' y' . y)
	Hide() => this.gui.Hide()
	__Delete() {
		this.gui.Destroy()
		if (this.HasOwnProp("hBitmap") && this.hBitmap) {
			DllCall("DeleteObject", "Ptr", this.hBitmap)
		}
	}
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
		app.rings[k] := Ring(Conf.diameter, Conf.thickness, v.border, Conf.ringTransparency)
	}
	for k, v in colors {
		if (k != "default") {
			app.circles[k] := SolidCircle(Conf.circleDiameter, v.back, Conf.circleTransparency)
			app.animCircles[k] := SolidCircle(Conf.startDiameter, v.back, Conf.startTransparency)
		}
	}
}

CleanupResources(*) {
	HideAllGraphics()
	if State.Hook {
		State.Hook.__Delete()
		State.Hook := ""
	}
	for key, hBitmap in Ring.hBitmapCache {
		DllCall("DeleteObject", "Ptr", hBitmap)
	}
	Ring.hBitmapCache.Clear()
	ShutdownGDIPlus()
}
