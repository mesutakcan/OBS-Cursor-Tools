; The GDI+ rendering code uses a reduced set of functions derived
; from Gdip_All.ahk(https://github.com/buliasz/AHKv2-Gdip/blob/master/Gdip_All.ahk)
; from the AHKv2-Gdip(https://github.com/buliasz/AHKv2-Gdip) project.

Gdip_Startup()
{
	if (!DllCall("LoadLibrary", "str", "gdiplus", "UPtr")) {
		throw Error("Could not load GDI+ library")
	}

	si := Buffer(A_PtrSize = 4 ? 20 : 32, 0)
	NumPut("uint", 0x2, si)
	NumPut("uint", 0x4, si, A_PtrSize = 4 ? 16 : 24)
	DllCall("gdiplus\GdiplusStartup", "UPtr*", &pToken := 0, "Ptr", si, "UPtr", 0)
	if (!pToken) {
		throw Error("Gdiplus failed to start. Please ensure you have gdiplus on your system")
	}

	return pToken
}

Gdip_Shutdown(pToken)
{
	DllCall("gdiplus\GdiplusShutdown", "UPtr", pToken)
	hModule := DllCall("GetModuleHandle", "str", "gdiplus", "UPtr")
	if (!hModule) {
		throw Error("GDI+ library was unloaded before shutdown")
	}
	if (!DllCall("FreeLibrary", "UPtr", hModule)) {
		throw Error("Could not free GDI+ library")
	}

	return 0
}

Gdip_CreateBitmap(Width, Height, Format := 0x26200A)
{
	DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", Width, "Int", Height, "Int", 0, "Int", Format, "UPtr", 0, "UPtr*", &pBitmap := 0)
	return pBitmap
}

Gdip_GraphicsFromImage(pBitmap)
{
	DllCall("gdiplus\GdipGetImageGraphicsContext", "UPtr", pBitmap, "UPtr*", &pGraphics := 0)
	return pGraphics
}

Gdip_CreateHBITMAPFromBitmap(pBitmap, Background := 0xffffffff)
{
	DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "UPtr", pBitmap, "UPtr*", &hbm := 0, "Int", Background)
	return hbm
}

Gdip_CreateARGBHBITMAPFromBitmap(&pBitmap)
{
	DllCall("gdiplus\GdipGetImageWidth", "ptr", pBitmap, "uint*", &width := 0)
	DllCall("gdiplus\GdipGetImageHeight", "ptr", pBitmap, "uint*", &height := 0)

	hdc := DllCall("CreateCompatibleDC", "ptr", 0, "ptr")
	bi := Buffer(40, 0)
	NumPut(
		"UInt", 40,
		"UInt", width,
		"Int", -height,
		"ushort", 1,
		"ushort", 32,
		bi)
	hbm := DllCall("CreateDIBSection", "ptr", hdc, "ptr", bi.Ptr, "UInt", 0, "ptr*", &pBits := 0, "ptr", 0, "UInt", 0, "ptr")
	obm := DllCall("SelectObject", "ptr", hdc, "ptr", hbm, "ptr")

	Rect := Buffer(16, 0)
	NumPut(
		"UInt", width,
		"UInt", height,
		Rect, 8)
	BitmapData := Buffer(16 + 2 * A_PtrSize, 0)
	NumPut(
		"UInt", width,
		"UInt", height,
		"Int", 4 * width,
		"Int", 0xE200B,
		"ptr", pBits,
		BitmapData)
	DllCall("gdiplus\GdipBitmapLockBits"
		, "ptr", pBitmap
		, "ptr", Rect.Ptr
		, "UInt", 5
		, "Int", 0xE200B
		, "ptr", BitmapData.Ptr)
	DllCall("gdiplus\GdipBitmapUnlockBits", "ptr", pBitmap, "ptr", BitmapData.Ptr)

	DllCall("SelectObject", "ptr", hdc, "ptr", obm)
	DllCall("DeleteDC", "ptr", hdc)

	return hbm
}

Gdip_GraphicsClear(pGraphics, ARGB := 0x00ffffff)
{
	return DllCall("gdiplus\GdipGraphicsClear", "UPtr", pGraphics, "Int", ARGB)
}

Gdip_SetSmoothingMode(pGraphics, SmoothingMode)
{
	return DllCall("gdiplus\GdipSetSmoothingMode", "UPtr", pGraphics, "Int", SmoothingMode)
}

Gdip_DrawEllipse(pGraphics, pPen, x, y, w, h)
{
	return DllCall("gdiplus\GdipDrawEllipse", "UPtr", pGraphics, "UPtr", pPen, "Float", x, "Float", y, "Float", w, "Float", h)
}

Gdip_FillEllipse(pGraphics, pBrush, x, y, w, h)
{
	return DllCall("gdiplus\GdipFillEllipse", "UPtr", pGraphics, "UPtr", pBrush, "Float", x, "Float", y, "Float", w, "Float", h)
}

Gdip_DrawLine(pGraphics, pPen, x1, y1, x2, y2)
{
	return DllCall("gdiplus\GdipDrawLine"
		, "UPtr", pGraphics
		, "UPtr", pPen
		, "Float", x1
		, "Float", y1
		, "Float", x2
		, "Float", y2)
}

Gdip_BrushCreateSolid(ARGB := 0xff000000)
{
	DllCall("gdiplus\GdipCreateSolidFill", "UInt", ARGB, "UPtr*", &pBrush := 0)
	return pBrush
}

Gdip_CreatePen(ARGB, w)
{
	DllCall("gdiplus\GdipCreatePen1", "UInt", ARGB, "Float", w, "Int", 2, "UPtr*", &pPen := 0)
	return pPen
}

Gdip_DeletePen(pPen)
{
	return DllCall("gdiplus\GdipDeletePen", "UPtr", pPen)
}

Gdip_DeleteBrush(pBrush)
{
	return DllCall("gdiplus\GdipDeleteBrush", "UPtr", pBrush)
}

Gdip_DeleteGraphics(pGraphics)
{
	return DllCall("gdiplus\GdipDeleteGraphics", "UPtr", pGraphics)
}

Gdip_DisposeImage(pBitmap)
{
	return DllCall("gdiplus\GdipDisposeImage", "UPtr", pBitmap)
}