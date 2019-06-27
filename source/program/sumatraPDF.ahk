﻿#IfWinActive, ahk_exe SumatraPDF.exe
	; Bookmarks panel.
	^b::Send, {F12}
	
	; Kill unconventional hotkey to quit.
	^q::return
	
	; Find forward/back.
	^g::F3
	^+g::+F3
	
	; Save as is Ctrl+S
	^+s::Send, ^s
	
	; Want to close on Esc, but also just unfocus search box if that's focused.
	Escape::
		if(ControlGetFocus("A") = "Edit2")
			Send, {Tab}
		else
			WinClose
	return
#IfWinActive
