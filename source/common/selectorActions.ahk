; Central place for functions called from Selector.
; All of them should take just one argument, a SelectorRow object (defined in selectorRow.ahk), generally named actionRow.
; There's also a debug mode that most of these should support:
;	You can check whether we're in debug mode via the flag actionRow.debugResult (boolean)
;	If we're in debug mode, the function should NOT perform its usual action, but should instead set actionRow.debugResult to what it WOULD be doing otherwise.
;		For example, if a function normally runs an executable with arguments:
;			Run, C:\full\path\to\executable.exe /a fileNameAndStuff
;		Then when debug mode is on it might store the full string is WOULD have run:
;			actionRow.debugResult := "C:\full\path\to\executable.exe /a fileNameAndStuff"
;	The Selector itself will show that result via DEBUG.popup(), which will show the contents of that variable in a popup.
;		Note that DEBUG.popup() handles objects and will drill down into them, see that class (defined in debug.ahk) for details.


; == Return functions (just return the actionRow object or a specific piece of it) ==
; Just return the requested subscript (defaults to "DOACTION").
RET(actionRow, subToReturn = "DOACTION") {
	if(actionRow.isDebug) ; Debug mode.
		actionRow.debugResult := actionRow.data[subToReturn]
	
	return actionRow.data[subToReturn]
}

; Return data array, for when we want more than just one value back.
RET_DATA(actionRow) {
	if(actionRow.isDebug) ; Debug mode.
		actionRow.debugResult := actionRow.data
	
	return actionRow.data
}

; Return entire object.
RET_OBJ(actionRow) {
	if(actionRow.isDebug) ; Debug mode.
		actionRow.debugResult := actionRow
	
	return actionRow
}


; == Run functions (simply run DOACTION subscript of the actionRow object) ==
; Run the action.
DO(actionRow) {
	if(actionRow.isDebug) ; Debug mode.
		actionRow.debugResult := actionRow
	else
		Run, % actionRow.data["DOACTION"]
}
	
; Run the action, waiting for it to finish.
DO_WAIT(actionRow) {
	if(actionRow.isDebug) ; Debug mode.
		actionRow.debugResult := actionRow
	else
		RunWait, % actionRow.data["DOACTION"]
}


; == File operations ==
; Write to the windows registry.
REG_WRITE(actionRow) {
	keyName   := actionRow.data["KEY_NAME"]
	keyValue  := actionRow.data["KEY_VALUE"]
	keyType   := actionRow.data["KEY_TYPE"]
	rootKey   := actionRow.data["ROOT_KEY"]
	regFolder := actionRow.data["REG_FOLDER"]
	
	if(actionRow.isDebug) ; Debug mode.
		actionRow.debugResult := {"Key name":keyName, "Key value":keyValue, "Key Type":keyType, "Root key":rootKey, "Key folder":regFolder}
	else
		RegWrite, %keyType%, %rootKey%, %regFolder%, %keyName%, %keyValue%
}

; Change a value in an ini file.
INI_WRITE(actionRow) {
	offStrings := ["o", "f", "off", "0"]
	
	if(actionRow.data["FILE"]) {
		file := actionRow.data["FILE"]
		sect := actionRow.data["SECTION"]
		key  := actionRow.data["KEY"]
		val  := actionRow.data["VALUE"]
		
	; Special debug case - key from name, value from arbitrary end.
	} else {
		file := actionRow.data["KEY"]
		sect := actionRow.data["VALUE"]
		key  := actionRow.data["NAME"]
		val  := !contains(offStrings, actionRow.userInput)
	}
	
	if(actionRow.isDebug) { ; Debug mode.
		actionRow.debugResult := {"File":file, "Section":sect, "Key":key, "Value":val}
		return
	}
	
	if(!val) ; Came from post-pended arbitrary piece.
		IniDelete, %file%, %sect%, %key%
	else
		IniWrite, %val%, %file%, %sect%, %key%
}

; Updates specific settings out of the main script's configuration file, then reloads it.
UPDATE_AHK_SETTINGS(actionRow) {
	global MAIN_CENTRAL_SCRIPT
	INI_WRITE(actionRow) ; Has its own debug handling.
	
	; Also reload the script to reflect the updated settings.
	if(actionRow.isDebug) ; Debug mode.
		return ; actionRow.debugResult already set by INI_WRITE.
	else
		reloadScript(MAIN_CENTRAL_SCRIPT, true)
}


; == Open specific programs ==
; Run Hyperspace.
DO_HYPERSPACE(actionRow) {
	environment  := actionRow.data["COMM_ID"]
	versionMajor := actionRow.data["MAJOR"]
	versionMinor := actionRow.data["MINOR"]
	
	; Error check.
	if(!versionMajor || !versionMinor) {
		DEBUG.popup("DO_HYPERSPACE", "Missing info", "Major version", versionMajor, "Minor version", versionMinor)
		return
	}
	
	; Build run path.
	runString := callIfExists("buildHyperspaceRunString", versionMajor, versionMinor, environment) ; buildHyperspaceRunString(versionMajor, versionMinor, environment)
	
	; Do it.
	if(actionRow.isDebug) ; Debug mode.
		actionRow.debugResult := runString
	else
		Run, % runString
}

; Send internal ID of an environment.
SEND_ENVIRONMENT_ID(actionRow) {
	environmentId := actionRow.data["ENV_ID"]
	
	; Do it.
	if(actionRow.isDebug) ; Debug mode.
		actionRow.debugResult := environmentId
	else
		Send, % environmentId
		Send, {Enter} ; Submit it too.
}

; Run something through Thunder, generally a text session or Citrix.
DO_THUNDER(actionRow) {
	runString := ""
	thunderId := actionRow.data["THUNDER_ID"]
	
	runString := MainConfig.getProgram("Thunder", "PATH") " " thunderId
	
	; Do it.
	if(actionRow.data["COMM_ID"] = "LAUNCH") ; Special keyword - just show Thunder itself, don't launch an environment.
		activateProgram("Thunder")
	else if(actionRow.isDebug)               ; Debug mode.
		actionRow.debugResult := runString
	else
		Run, % runString
}

; Run a VDI.
DO_VDI(actionRow) {
	vdiId := actionRow.data["VDI_ID"]
	
	; Build run path.
	runString := callIfExists("buildVDIRunString", vdiId) ; buildVDIRunString(vdiId)
	
	; Do it.
	if(actionRow.data["COMM_ID"] = "LAUNCH") { ; Special keyword - just show VMWare itself, don't launch a specific VDI.
		runProgram("VMWareView")
	} else if(actionRow.isDebug) {             ; Debug mode.
		actionRow.debugResult := runString
	} else {
		Run, % runString
		
		; Also fake-maximize the window once it shows up.
		WinWaitActive, ahk_exe vmware-view.exe, , , VMware Horizon Client ; Ignore the loading-type popup that happens initially with excluded title.
		fakeMaximizeWindow()
	}
}

; Open an environment in Snapper using a dummy record.
DO_SNAPPER(actionRow) {
	environment := actionRow.data["COMM_ID"]
	ini         := actionRow.data["INI"]
	idList      := actionRow.data["ID"]
	
	url := callIfExists("buildSnapperURL", environment, ini, idList) ; buildSnapperURL(environment, ini, idList)
	
	; Do it.
	if(actionRow.data["COMM_ID"] = "LAUNCH") ; Special keyword - just launch Snapper, not any specific environment.
		runProgram("Snapper")
	else if(actionRow.isDebug)               ; Debug mode.
		actionRow.debugResult := url
	else
		Run, % url
}

; Open a homebrew timer (script located in the filepath below).
TIMER(actionRow) {
	time := actionRow.data["TIME"]
	runString := MainConfig.getFolder("AHK_ROOT") "\source\standalone\timer\timer.ahk " time
	
	; Do it.
	if(actionRow.isDebug) ; Debug mode.
		actionRow.debugResult := runString
	else
		Run, % runString
}


; == Other assorted action functions ==
; Call a phone number.
CALL(actionRow) {
	num := actionRow.data["NUMBER"]
	special := actionRow.data["SPECIAL"]
	
	if(actionRow.isDebug) { ; Debug mode.
		actionRow.debugResult := {"Number":num, "Special":special}
		return
	}
	
	if(special = "SEARCH") { ; Use QuickDial to search for the given name (not a number)
		callIfExists("activateProgram", "QuickDialer") ; activateProgram("QuickDialer")
		WinWaitActive, Quick Dial
		if(num != "SEARCH")
			SendRaw, %num%
	} else {
		callIfExists("callNumber", num, actionRow.data["NAME"]) ; callNumber(num, actionRow.data["NAME"])
	}
}

; Resizes the active window to the given dimensions.
RESIZE(actionRow) {
	width  := actionRow.data["WIDTH"]
	height := actionRow.data["HEIGHT"]
	ratioW := actionRow.data["WRATIO"]
	ratioH := actionRow.data["HRATIO"]
	
	if(ratioW)
		width *= ratioW
	if(ratioH)
		height *= ratioH
	
	; Do it.
	if(actionRow.isDebug) ; Debug mode.
		actionRow.debugResult := {"Width":width, "Height":height}
	else
		WinMove, A, , , , width, height
}

; Builds a string to add to a calendar event (with the format the outlook/tlg calendar needs to import happily into Delorean), then sends it and an Enter keystroke to save it.
OUTLOOK_TLG(actionRow) {
	tlp      := actionRow.data["TLP"]
	message  := actionRow.data["MSG"]
	dlg      := actionRow.data["DLG"]
	customer := actionRow.data["CUST"]
	
	; Sanity check - if the message is an EMC2 ID (or P.emc2Id) and the DLG is not, swap them.
	if(!isEMC2Id(dlg) && (SubStr(dlg, 1, 2) != "P.") ) {
		if(isEMC2Id(message)) {
			newDLG  := message
			message := dlg
			dlg     := newDLG
		}
	}
	
	actionRow.data["DOACTION"] := tlp "/" customer "///" dlg ", " message
	
	; Do it.
	if(actionRow.isDebug) { ; Debug mode.
		actionRow.debugResult := actionRow.data["DOACTION"]
	} else {
		; focusedControl := getFocusedControl()
		textToSend := actionRow.data["DOACTION"]
		SendRaw, % textToSend
		Send, {Enter}
		; ControlSendRaw, %focusedControl%, %textToSend%, ahk_class rctrl_renwnd32
		; ControlSend, %focusedControl%, {Enter}, ahk_class rctrl_renwnd32
	}
}

; Builds and sends a string to exclude the items specified, for Snapper.
SEND_SNAPPER_EXCLUDE_ITEMS(actionRow) {
	itemsList := actionRow.data["STATUS_ITEMS"]
	itemsAry := StrSplit(itemsList, ",")
	
	For i,item in itemsAry {
		if(i > 1)
			excludeItemsString .= ","
		excludeItemsString .= "-" item
	}
	
	; Do it.
	if(actionRow.isDebug) { ; Debug mode.
		actionRow.debugResult := excludeItemsString
	} else {
		Send, % excludeItemsString
		Send, {Enter}
	}
}
