class Putty {
	;region ------------------------------ INTERNAL ------------------------------
	; IDM_RECONF, found in Putty's source code in window.c: https://github.com/codexns/putty/blob/master/windows/window.c
	static ChangeSettingsOption := 0x50
	
	;---------
	; DESCRIPTION:    Wipe the screen, optionally also clearing scrollback.
	; PARAMETERS:
	;  clearScrollback (I,OPT) - Set to true to also clear scrollback.
	;---------
	wipeScreen(clearScrollback := false) {
		Send, !{Space} ; Open menu
		Send, t        ; Reset terminal
		
		if(clearScrollback) {
			Send, !{Space}
			Send, l ; Clear scrollback
		}
		
		Sleep, 100
		Send, {Enter} ; Show prompt
	}
	
	;---------
	; DESCRIPTION:    Prompt for some text, then insert it (without overwriting) by inserting spaces.
	;---------
	insertArbitraryText() {
		; Popup to get the text.
		textIn := InputBox("Insert text (without overwriting)", , , 500, 100)
		if(textIn = "")
			return
		
		; Get the length of the string we're going to add.
		inputLength := textIn.length()
		
		; Insert that many spaces.
		Send, {Insert %inputLength%}
		
		; Actually send our input text.
		SendRaw, % textIn
	}
	
	;---------
	; DESCRIPTION:    Search within record edit screens with Home+F9 functionality.
	; PARAMETERS:
	;  usePrevious (I,OPT) - Set to true to use the last search type/text instead of prompting the
	;                        user. This is ignored if there was no last search type/text.
	; SIDE EFFECTS:   Sets Putty.LastSearch_* to whatever is chosen here for re-use later.
	;---------
	recordEditSearch(usePrevious := false) {
		; Start with the last search type/text if requested.
		if(usePrevious) {
			searchType := Putty.LastSearch_Type
			searchText := Putty.LastSearch_Text
		}
	
		; If no previous values (or not using them), prompt the user for how/what to search.
		if(searchType = "" || searchText = "") {
			data := new Selector("puttyRecordEditSearch.tls").prompt()
			searchType := data["SEARCH_TYPE"]
			searchText := data["SEARCH_TEXT"]
		}
		
		; If still nothing, bail.
		if(searchType = "" || searchText = "")
			return
		
		; Run the search.
		Send, {Home}{F9}
		Send, %searchType%{Enter}
		SendRaw, % searchText
		Send, {Enter}
		
		; Store off the latest search for use with ^g later.
		Putty.LastSearch_Type := searchType
		Putty.LastSearch_Text := searchText
	}

	;---------
	; DESCRIPTION:    Open the Change Settings menu
	;---------
	openSettingsWindow() {
		PostMessage, MicrosoftLib.Message_WindowMenu, Putty.ChangeSettingsOption, 0
	}
	
	;---------
	; DESCRIPTION:    Open the current log file
	;---------
	openCurrentLogFile() {
		logFilePath := Putty.getLogFilePath()
		if(logFilePath)
			Run(logFilePath)
	}
	;endregion ------------------------------ INTERNAL ------------------------------
	
	;region ------------------------------ PRIVATE ------------------------------
	; For Home+F9 searching repeatedly.
	static LastSearch_Type := ""
	static LastSearch_Text := ""
	
	;---------
	; DESCRIPTION:    Get the log file for the current Putty session via the settings window.
	; RETURNS:        The path to the log file
	; SIDE EFFECTS:   Temporarily opens the settings window, then closes it.
	;---------
	getLogFilePath() {
		if(!WinActive("ahk_class PuTTY"))
			return ""
		
		Putty.openSettingsWindow()
		
		; Wait for the popup to show up
		WinWaitActive, ahk_class PuTTYConfigBox
		
		Send, !g ; Category pane
		Send, l  ; Logging tree node
		Sleep, 500
		Send, !f ; Log file name field
		
		logFile := SelectLib.getText()
		
		Send, !c ; Cancel
		return logFile
	}
	;endregion ------------------------------ PRIVATE ------------------------------
}
