; Epic-specific functions.

{ ; Epic Object-related things.
	getRelatedQANsAry() {
		if(!MainConfig.isWindowActive("EMC2"))
			return ""
		
		; Assuming you're in the first row of the table already.
		
		outAry := []
		Loop {
			Send, {End}
			Send, {Left}
			Send, {Ctrl Down}{Shift Down}
			Send, {Left}
			Send, {Ctrl Up}
			Send, {Right}
			Send, {Shift Up}
			
			qan := getSelectedText()
			if(!qan)
				break
			
			Send, {Tab}
			version := getSelectedText()
			
			; Avoid duplicate entries (for multiple versions
			if(qan != oldQAN)
				outAry.push(qan)
			
			; Loop quit condition - same QAN again (table ends on last filled row), also same version
			if( (qan = oldQAN) && (version = oldVersion) )
				break
			oldQAN     := qan
			oldVersion := version
			
			Send, +{Tab}
			Send, {Down}
		}
		
		return outAry
	}

	buildQANURLsAry(relatedQANsAry) {
		if(!relatedQANsAry)
			return ""
		
		urlsAry := []
		For _,qan in relatedQANsAry {
			ao := new ActionObjectEMC2(qan, "QAN")
			link := ao.getLinkWeb()
			if(link)
				urlsAry.push(link)
		}
		
		return urlsAry
	}
}

{ ; Phone-related functions.
	; Dials a given number using the Cisco WebDialer API.
	callNumber(formattedNum, name := "") {
		; Get the raw number (with leading digits as needed) to plug into the URL.
		rawNum := parsePhone(formattedNum)
		if(!rawNum) {
			MsgBox, % "Invalid phone number."
			return
		}
		
		; Confirm the user wants to call.
		if(!userWantsToCall(formattedNum, rawNum, name))
			return
		
		; Build the URL.
		url := getDialerURL(rawNum)
		if(!url)
			return
		
		; Dial with a web request.
		HTTPRequest(url, In := "", Out := "")
		; DEBUG.popup("callNumber","Finish", "Input",formattedNum, "Raw number",rawNum, "Name",name, "URL",url)
	}
	
	userWantsToCall(formattedNum, rawNum, name := "") {
		if(!formattedNum || !rawNum)
			return false
		
		if(formattedNum = "HANGUP") {
			title          := "Hang up?"
			messageText    := "Hanging up current call. `n`nContinue?"
		} else {
			title          := "Dial number?"
			messageText    := "Calling: `n`n"
			if(name)
				messageText .= name "`n"
			messageText    .= formattedNum "`n"
			messageText    .= "[" rawNum "] `n`n"
			messageText    .= "Continue?"
		}
		
		MsgBox, % MSGBOX_BUTTONS_YES_NO, % title, % messageText
		IfMsgBox Yes
			return true
		return false
	}
	
	; Generates a Cisco WebDialer URL to call a number.
	getDialerURL(rawNum) {
		if(!rawNum)
			return ""
		
		if(rawNum = "HANGUP")
			command := "HangUpCall?"
		else
			command := "CallNumber?extension=" rawNum
		
		return replaceTag(MainConfig.private["CISCO_PHONE_BASE"], "COMMAND", command)
	}
}

{ ; Run path/URL-building functions
	buildHyperspaceRunString(versionMajor, versionMinor, environment) {
		runString := MainConfig.private["HYPERSPACE_BASE"]
		
		; Handling for 2010 special path.
		if(versionMajor = 7 && versionMinor = 8)
			runString := replaceTag(runString, "EPICNAME", "EpicSys")
		else
			runString := replaceTag(runString, "EPICNAME", "Epic")
		
		; Versioning and environment.
		runString := replaceTags(runString, {"MAJOR":versionMajor, "MINOR":versionMinor, "ENVIRONMENT":environment})
		
		; DEBUG.popup("Start string", tempRun, "Finished string", runString, "Major", versionMajor, "Minor", versionMinor, "Environment", environment)
		return runString
	}

	buildTxDumpRunString(txId, environmentCommId := "", environmentName := "") {
		if(!txId)
			return ""
		
		; Build the full output filepath.
		if(!environmentName)
			if(environmentCommId)
				environmentName := environmentCommId
			else
				environmentName := "OTHER"
		outputPath := MainConfig.path["TX_DIFF_OUTPUT"] "\" txId "-" environmentName ".txt"
		
		; Build the string to run
		runString := MainConfig.private["TX_DIFF_DUMP_BASE"]
		runString := replaceTag(runString, "TX_ID",       txId)
		runString := replaceTag(runString, "OUTPUT_PATH", outputPath)
		
		; Add on the environment if it's given - if not, leave off the flag (which will automatically cause the script to show an environment selector instead).
		if(environmentCommId)
			runString .= " --env " environmentCommId
		
		; DEBUG.popup("buildTxDumpRunString","Finish", "txId",txId, "outputFolder",outputFolder, "environmentCommId",environmentCommId, "runString",runString)
		return runString
	}

	buildCodeSearchURL(searchTerm, searchType, appKey := "") {
		appId := getEpicAppIdFromKey(appKey)
		; DEBUG.popup("buildCodeSearchURL", "Start", "Search type", searchType, "Search term", searchTerm, "App key", appKey, "App ID", appId)
		
		; Gotta have something to search for (and a type) to run a search.
		if(!searchTerm || !searchType)
			return ""
		
		criteriaString := "a=" searchTerm
		return replaceTags(MainConfig.private["CS_BASE"], {"SEARCH_TYPE":searchType, "APP_ID":appId, "CRITERIA":criteriaString})
	}
	getEpicAppIdFromKey(appKey) {
		if(!appKey)
			return 0
		return MainConfig.private["CS_APP_ID_" appKey]
	}

	buildGuruURL(searchTerm) {
		return MainConfig.private["GURU_SEARCH_BASE"] searchTerm
	}

	buildEpicWikiSearchURL(searchTerm, category := "") {
		outURL := MainConfig.private["WIKI_SEARCH_BASE"]
		outURL := replaceTag(outURL, "QUERY", searchTerm)
		
		if(category) {
			category := "'" category "'"
			outURL .= MainConfig.private["WIKI_SEARCH_FILTERS"]
			outURL := replaceTag(outURL, "CATEGORIES", category)
		}
		
		return outURL
	}

	; ini/id defaults are "X" as a dummy - URL will still connect to desired environment (and show an error popup).
	buildSnapperURL(environment := "", ini := "", idList := "") { ; idList is a comma-separated list of IDs
		if(!environment)
			environment := getCurrentSnapperEnvironment() ; Try to default from what Snapper has open right now if no environment given.
		if(!environment)
			return ""
		
		if(!ini || !idList) { ; These aren't be parameter defaults in case of blank parameters (not simply not passed at all)
			ini    := "X"
			idList := "X"
		}
		
		outURL := MainConfig.private["SNAPPER_URL_BASE"]
		idAry := expandList(idList)
		if(idAry.count() > 10)
			if(!showConfirmationPopup("You're trying to open more than 10 records in Snapper - are you sure you want to continue?", "Opening many records in Snapper"))
				return ""
		
		For i,id in idAry {
			; DEBUG.popup("Index", i, "ID", id)
			if(!id)
				Continue
			
			outURL .= ini "." id "." environment "/"
		}
		
		return outURL
	}
	getCurrentSnapperEnvironment() {
		snapperTitleString := "Snapper ahk_exe Snapper.exe"
		if(!WinExist(snapperTitleString))
			return ""
		
		environmentText := ControlGetText("ThunderRT6ComboBox2", snapperTitleString)
		commId := getFirstStringBetweenStr(environmentText, "[", "]")
		
		return commId
	}

	buildVDIRunString(vdiId) {
		return replaceTag(MainConfig.private["VDI_BASE"], "VDI_ID", vdiId)
	}

	buildEpicStudioRoutineLink(routine, tag := "", environmentId := "", diffEnvironmentId := "") {
		if(routine = "")
			return ""
		
		if(environmentId = "")
			environmentId := MainConfig.private["DBC_DEV_ENV_ID"] ; Default to DBC Dev if environment not given
		
		url := MainConfig.private["EPICSTUDIO_URL_BASE_ROUTINE"]
		
		url := replaceTag(url, "ROUTINE", routine)
		url := replaceTag(url, "TAG", tag)
		
		environmentParam := environmentId
		if(diffEnvironmentId != "")
			environmentParam .= "|" diffEnvironmentId
		url := replaceTag(url, "ENVIRONMENT", environmentParam)
		
		return url
	}
	
	buildEpicStudioDLGLink(dlgId) {
		if(dlgId = "")
			return ""
		
		url := MainConfig.private["EPICSTUDIO_URL_BASE_DLG"]
		url := replaceTag(url, "DLG_ID", dlgId)
		
		return url
	}
}

; Split "INI ID" string into INI and ID (assume it's just the ID if no space included).
; Also does cleaning around the string so leading/trailing spaces, bullets, etc. don't make it fail.
splitRecordString(recordString, ByRef ini := "", ByRef id := "") {
	recordString := cleanupText(recordString)
	recordPartsAry := StrSplit(recordString, " ")
	
	maxIndex := recordPartsAry.MaxIndex()
	if(maxIndex > 1)
		ini := recordPartsAry[1]
	id := recordPartsAry[maxIndex] ; Always the last piece (works whether there was an INI before it or not)
}

; Split serverLocation into routine and tag (assume it's just the routine if no ^ included).
; Note that any offset from a tag will be included in the tag return value (i.e. TAG+3^ROUTINE splits into routine=ROUTINE and tag=TAG+3).
splitServerLocation(serverLocation, ByRef routine := "", ByRef tag := "") {
	serverLocation := cleanupText(serverLocation, ["$", "(", ")"])
	locationAry := StrSplit(serverLocation, "^")
	
	maxIndex := locationAry.MaxIndex()
	if(maxIndex > 1)
		tag := locationAry[1]
	routine := locationAry[maxIndex] ; Always the last piece (works whether there was a tag before it or not)
}

; Drop the offset ("+4" in "tag+4^routine") from the given server location (so we'd return "tag^routine").
dropOffsetFromServerLocation(serverLocation) {
	splitServerLocation(serverLocation, routine, tag)
	tag := getStringBeforeStr(tag, "+")
	return tag "^" routine
}

; line = title of EMC2 email, or title from top of web view.
extractEMC2ObjectInfo(line) {
	infoAry := extractEMC2ObjectInfoRaw(line)
	return processEMC2ObjectInfo(infoAry)
}
extractEMC2ObjectInfoRaw(line) {
	line := cleanupText(line, ["["]) ; Remove any odd leading/trailing characters (and also remove open brackets)
	
	; INI is first characters up to the first delimiter
	delimPos := stringMatchesAnyOf(line, [" ", "#"])
	if(delimPos) {
		ini  := subStr(line, 1, delimPos - 1)
		line := subStr(line, delimPos + 1) ; +1 to drop delimiter too
	}
	
	; ID is remaining up to the next delimiter
	delimPos := stringMatchesAnyOf(line, [" ", ":", "-", "]"])
	if(!delimPos) { ; If the string ended before the next delimiter (so no title), make sure to still get the ID.
		id := subStr(line, 1, strLen(line))
		line := ""
	} else {
		id := subStr(line, 1, delimPos - 1)
		line := subStr(line, delimPos + 1) ; +1 to drop delimiter too
	}
	
	; Title is everything left
	title := line
	
	return {"INI":ini, "ID":id, "TITLE":title}
}
processEMC2ObjectInfo(infoAry) {
	ini   := infoAry["INI"]
	id    := infoAry["ID"]
	title := infoAry["TITLE"]
	
	; INI
	s := new Selector("actionObject.tls")
	ini := s.select(ini, "SUBTYPE") ; Turn any not-really-ini strings (like "Design") into actual INI (and ask user if we don't have one)
	if(!ini)
		return ""
	
	; ID
	id := cleanupText(id)
	
	; Title
	stringsToRemove := ["-", "/", "\", ":", ",", "(Developer has reset your status)", "(Stage 1 QAer is Waiting for Changes)", "(Stage 2 QAer is Waiting for Changes)", "(A Reviewer Approved)"] ; Odd characters and non-useful strings that should come off
	title := cleanupText(title, stringsToRemove)
	title := removeStringFromStart(title, "DBC") ; Drop from start - most of my DLGs are DBC, no reason to include that.
	title := cleanupText(title, stringsToRemove) ; Remove anything that might have been after the "DBC"
	if(ini = "SLG") {
		; "--Assigned to: USER" might be on the end for SLGs - trim it off.
		title := getStringBeforeStr(title, "--Assigned To:")
	}
	
	return {"INI":ini, "ID":id, "TITLE":title}
}

; Returns standard string for OneNote use.
buildStandardEMC2ObjectString(ini, id, title) {
	return ini " " id " - " title
}

; Turn descriptors that aren't real INIs (like "Design") into the corresponding EMC2 INI.
getTrueEMC2INI(iniString) {
	if(!iniString)
		return ""
	
	s := new Selector("actionObject.tls")
	return s.selectChoice(iniString, "SUBTYPE")
}


getObjectInfoFromEMC2(ByRef ini := "", ByRef id := "") {
	title := WinGetTitle(MainConfig.windowInfo["EMC2"].titleString)
	title := removeStringFromEnd(title, " - EMC2")
	
	; If no info available, finish here.
	if((title = "") or (title = "EMC2"))
		return
	
	; Split the input.
	splitRecordString(title, ini, id)
	; DEBUG.popup("getObjectInfoFromEMC2","Finish", "INI",ini, "ID",id)
}
