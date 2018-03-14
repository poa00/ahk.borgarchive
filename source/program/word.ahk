; Word hotkeys.
#IfWinActive, ahk_class OpusApp
	; Save as, ctrl shift s.
	^+s::
		Send !fa
	return
	
	; Jump to next *** token and select it.
	F2::
		Send, ^g         ; Find/replace popup (Go To tab)
		Send, !d         ; Find tab
		Send, !n         ; Focus "Find what" field
		Send, ***        ; String to search for
		Send, !:         ; Focus "Search" (direction) dropdown
		Send, A          ; Search "All"
		Send, !f         ; Find next
		Send, {Esc}      ; Get out of the find popup/navigation pane
		
		; If the find popup is still open (presumably because we hit the "finished searching" popup), close it.
		if(WinActive("Find and Replace"))
			Send, {Esc}   ; Close the popup
		
	return
#IfWinActive
