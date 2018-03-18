﻿#IfWinActive, ahk_exe Snapper.exe
	; Send string of status items to ignore, based on the given master file.
	:*:.status::
		doSelect("local\chroniclesStatusItems.tl")
	return
#IfWinActive

; Add record window
#IfWinActive, Add a Record ahk_exe Snapper.exe
	^Enter::
		addMultipleRecordsToSnapper() {
			url := getSnapperURLFromAddRecordPopup()
			if(url) {
				Send, !c ; Close add record popup (can't use WinClose as that triggers validation on ID field)
				WinWaitActive, Snapper
				Run, % url
			} else {
				Send, {Enter}
			}
		}
#IfWinActive

getSnapperURLFromAddRecordPopup() {
	commId := getCurrentSnapperEnvironment()
	ini := ControlGetText("ThunderRT6TextBox1", "Add a Record ahk_exe Snapper.exe")
	idList := ControlGetText("ThunderRT6TextBox2", "Add a Record ahk_exe Snapper.exe")
	
	if(!commId || !ini || !idList)
		return ""
	
	return buildSnapperURL(commId, ini, idList)
}