; Jikkelsen, 2020
; 
; Makes locking the screen cooler 
;

#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance, Force

FULL 			:= A_ScriptDir "\Lock.png"
SMALL			:= A_ScriptDir "\Lock_small.png"
BIG				:= A_ScriptDir "\Lock_big.png"
LockImage		:= A_ScriptDir "\alock.png"

F8::
TakeScreenshot(FULL)
convert_resize(FULL,SMALL,"k_ratio",0.2 )
convert_resize(SMALL,BIG,"k_ratio",5 )
CombineImages(BIG, LockImage, FULL)
gosub, SubRoutine
DllCall("user32.dll\LockWorkStation")
return


; -------------------------------------- functions -------------------------------------------

TakeScreenshot(FileName)
; beaucoup thanks to tic (Tariq Porter) for his GDI+ Library
; https://autohotkey.com/boards/viewtopic.php?t=6517
; https://github.com/tariqporter/Gdip/raw/master/Gdip.ahk
{
	pToken:=Gdip_Startup()
	If (pToken=0)
	{
	MsgBox,4112,Fatal Error,Unable to start GDIP
	}
	pBitmap:=Gdip_BitmapFromScreen()
	If (pBitmap<=0)
	{
	MsgBox,4112,Fatal Error,pBitmap=%pBitmap% trying to get bitmap from the screen
	ExitApp
	}
	Gdip_SaveBitmapToFile(pBitmap,FileName)
	If (ErrorLevel<>0)
	{
	MsgBox,4112,Fatal Error,ErrorLevel=%ErrorLevel% trying to save bitmap to`n%FileName%
	ExitApp
	}
	Return
}

convert_resize(source_file,out_file,function="",value=1){
	; Credit to Closed -> https://autohotkey.com/board/topic/52033-convertresize-image-with-gdip-solved/
	If !pToken := Gdip_Startup()
	{
		MsgBox, 48, gdiplus error!, Gdiplus failed to start. Please ensure you have gdiplus on your system
		ExitApp
	}

	pBitmapFile := Gdip_CreateBitmapFromFile(source_file)
	Width := Gdip_GetImageWidth(pBitmapFile), Height := Gdip_GetImageHeight(pBitmapFile)
	ratio=1
	if (function = "k_ratio")
	ratio:=value
	if (function = "k_width")
	ratio:=value/width
	if (function = "k_height")
	ratio:=value/height
	w:=floor(width*ratio)
	h:=floor(height*ratio)

	pBitmap := Gdip_CreateBitmap(w, h)
	G := Gdip_GraphicsFromImage(pBitmap)
	Gdip_DrawImage(G, pBitmapFile, 0, 0, w, h, 0, 0, Width, Height)
	Gdip_SaveBitmapToFile(pBitmap, out_file)

	Gdip_DisposeImage(pBitmapFile)
	Gdip_DisposeImage(pBitmap)
	Gdip_DeleteGraphics(G)
}


	;Credit to QWERTY12 -> https://www.autohotkey.com/boards/viewtopic.php?f=5&t=39967
	SubRoutine:
	; 1. Create StorageFile obj for pic
	VarSetCapacity(IIDStorageFileStatics, 16), VA_GUID(IIDStorageFileStatics := "{5984C710-DAF2-43C8-8BB4-A4D3EACFD03F}")
	StorageFile := new rtstr("Windows.Storage.StorageFile")
	if (!DllCall("combase.dll\RoGetActivationFactory", "Ptr", StorageFile.str, "Ptr", &IIDStorageFileStatics, "Ptr*", instStorageFile)) {
		if (!DllCall(NumGet(NumGet(instStorageFile+0)+6*A_PtrSize), "Ptr", instStorageFile, "Ptr", (_ := new rtstr(FULL)).str, "Ptr*", sfileasyncwrapper)) {
			; 2. Said SF obj gets created async. Keep checking (in a sync manner) to see if actual SF obj is created
			sfileasyncinfo := ComObjQuery(sfileasyncwrapper, IID_IAsyncInfo := "{00000036-0000-0000-C000-000000000046}")
			while (!DllCall(NumGet(NumGet(sfileasyncinfo+0)+7*A_PtrSize), "Ptr", sfileasyncinfo, "UInt*", status) && !status)
				Sleep 100
			if (status != 1)
				ExitApp 1
			
			; 3. It has! Finally take pointer to sf obj
			DllCall(NumGet(NumGet(sfileasyncwrapper+0)+8*A_PtrSize), "Ptr", sfileasyncwrapper, "Ptr*", sfile)
			
			; 4. Create LockScreen obj
			VarSetCapacity(IIDLockScreenStatics, 16), VA_GUID(IIDLockScreenStatics := "{3EE9D3AD-B607-40AE-B426-7631D9821269}")
			lockScreen := new rtstr("Windows.System.UserProfile.LockScreen")
			if (!DllCall("combase.dll\RoGetActivationFactory", "Ptr", lockScreen.str, "Ptr", &IIDLockScreenStatics, "Ptr*", instLockScreen)) {
				; Tell ls obj to set ls pic from sf obj
				DllCall(NumGet(NumGet(instLockScreen+0)+8*A_PtrSize), "Ptr", instLockScreen, "Ptr", sfile, "Ptr*", Operation)
				;~ Sleep 200 ; Note: it's better to do the sfileasyncinfo stuff again instead of a simple sleep like this to help ensure the lockScreen pic is set. mind, if your script is persistent, it mightn't matter
				ObjRelease(Operation)
				ObjRelease(instLockScreen)
			}
			
			ObjRelease(sfile)
			ObjRelease(sfileasyncinfo)
			ObjRelease(sfileasyncwrapper)
		}
		ObjRelease(instStorageFile)
	}

	class rtstr {
		static lpWindowsCreateString := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "combase.dll", "Ptr"), "AStr", "WindowsCreateString", "Ptr")
		static lpWindowsDeleteString := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "combase.dll", "Ptr"), "AStr", "WindowsDeleteString", "Ptr")

		__New(sourceString, length := 0) {
			this.str := !DllCall(rtstr.lpWindowsCreateString, "WStr", sourceString, "UInt", length ? length : StrLen(sourceString), "Ptr*", string) ? string : 0
		}

		__Delete() {
			DllCall(rtstr.lpWindowsDeleteString, "Ptr", this.str)
		}
	}

	; From Lexikos' VA.ahk: Convert string to binary GUID structure.
	VA_GUID(ByRef guid_out, guid_in="%guid_out%") {
		if (guid_in == "%guid_out%")
			guid_in :=   guid_out
		if  guid_in is integer
			return guid_in
		VarSetCapacity(guid_out, 16, 0)
		DllCall("ole32\CLSIDFromString", "wstr", guid_in, "ptr", &guid_out)
		return &guid_out
	}
	return



;~ CombineImages() {
CombineImages(File1, File2, outputDest) {
	; This function has a tonne of code from gdi+ ahk tutorial 6 written by tic (Tariq Porter)
	
	If !pToken := Gdip_Startup()
	{
		MsgBox, 48, gdiplus error!, Gdiplus failed to start. Please ensure you have gdiplus on your system
		ExitApp
	}

	; Create a screeensized pixel gdi+ bitmap (this will be the entire drawing area we have to play with)
	pBitmap := Gdip_CreateBitmap(A_ScreenWidth, A_ScreenHeight)

	; Get a pointer to the graphics of the bitmap, for use with drawing functions
	G := Gdip_GraphicsFromImage(pBitmap)

	; Get bitmaps for both the files we are going to be working with
	pBitmapFile1 := Gdip_CreateBitmapFromFile(File1)
	pBitmapFile2 := Gdip_CreateBitmapFromFile(File2)

	; Get the width and height of the 1st and 2nd bitmap
	Width := Gdip_GetImageWidth(pBitmapFile1), Height := Gdip_GetImageHeight(pBitmapFile1)
	Width2 := Gdip_GetImageWidth(pBitmapFile2), Height2 := Gdip_GetImageHeight(pBitmapFile2)

	; Draw the 1st bitmap (1st image) onto our "canvas" (the graphics of the original bitmap we created) with the same height and same width
	; at coordinates (25,30).....We will be ignoring the matrix parameter for now. This can be used to change opacity and colours when drawing
	Gdip_DrawImage(G, pBitmapFile1, 0, 0, Width, Height, 0, 0, Width, Height)

	; Do the same again for the 2nd file, but change the coordinates to (250,260).....
	Width := Gdip_GetImageWidth(pBitmapFile2), Height := Gdip_GetImageHeight(pBitmapFile2)
	Gdip_DrawImage(G, pBitmapFile2, A_ScreenWidth/2 - Width2/2, A_ScreenHeight/2 - Height2/2, Width, Height, 0, 0, Width, Height)
	Gdip_DisposeImage(pBitmapFile1), Gdip_DisposeImage(pBitmapFile2)
	Gdip_SaveBitmapToFile(pBitmap, outputDest)
	Gdip_DisposeImage(pBitmap)
	Gdip_DeleteGraphics(G)
	Gdip_Shutdown(pToken)

}