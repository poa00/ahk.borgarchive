; OneNote hotkeys.
#If MainConfig.isWindowActive("OneNote")
	; Format as code (using custom styles)
	^+c::
		oneNoteCustomStyles()
		Send, {Enter}
	return
	
	{ ; Quick access toolbar commands.
		; New Subpage
		$^+n::
			oneNoteNewSubpage()
		return
		; Promote Subpage
		^+[::
			oneNotePromoteSubpage()
		return
		; Demote Subpage (Make Subpage)
		^+]::
			oneNoteDemoteSubpage()
		return
		; Delete Page
		$^+d::
			; Confirmation to avoid accidental page deletion
			MsgBox, 4, Delete page?, Are you sure you want to delete this page?
			IfMsgBox, Yes
				oneNoteDeletePage()
		return
		; Create linked Specific page (using OneTastic macro)
		^l::
			oneNoteCreateLinkPageSpecSection()
		return
		; Create linked dev Specific page (using OneTastic macro)
		^+l::
			oneNoteCreateLinkDevPageSpecSection()
		return
	}
	
	{ ; Navigation.
		; Modded ctrl+tab, etc. hotkeys.
		XButton1::Send, ^{PgDn}
		^Tab::    Send, ^{PgDn}
		XButton2::Send, ^{PgUp}
		^+Tab::   Send, ^{PgUp}
		
		^PgDn::Send, ^{Tab}
		^PgUp::Send, ^+{Tab}
		
		; Expand and collapse outlines.
		!Left::!+-
		!Right::!+=
		; Only Today section, sub-items hidden
		^t::
			Send, ^{Home} ; Overall Do header so we affect the whole page
			Send, !+4     ; Top level that today's todos are at (so they're all collapsed)
			Send, !+3     ; Collapse to headers under Today (which collapses headers under Today so only unfinished todos on level 4 are visible)
		return
		; All sections expanded
		^+t::
			Send, ^{Home}
			Send, !+4     ; Items for all sections (level 4)
		return
		; Expanded Today section
		^!t::
			Send, ^{Home}
			Send, !+5     ; Sub-items for all sections (level 5)
			Send, !+3     ; Top level for today's todos
		return
		
		; Replacement history back/forward.
		!+Left:: Send, !{Left}
		!+Right::Send, !{Right}
		
		; Horizontal scrolling.
		+WheelUp::
			onenoteScrollLeft() {
				MouseGetPos, , , winId, controlId, 1
				SendMessage, WM_HSCROLL, SB_LINELEFT, , % controlId, % "ahk_id " winId
			}
		+WheelDown::
			onenoteScrollRight() {
				MouseGetPos, , , winId, controlId, 1
				SendMessage, WM_HSCROLL, SB_LINERIGHT, , % controlId, % "ahk_id " winId
			}
	}
	
	{ ; Content/formatting modifiers.
		; Deletes a full line.
		^d::
			escapeOneNotePastePopup()
			Send, {Home}   ; Make sure the line isn't already selected, otherwise we select the whole parent.
			Send, ^a       ; Select all - gets entire line, including newline at end.
			Send, {Delete}
		return
		
		; Make line movement alt + up/down instead of alt + shift + up/down to match notepad++ and ES.
		!Up::!+Up
		!Down::!+Down
		
		; 'Normal' text formatting, as ^+n is already being used for new subpage.
		^!n::
			Send, ^+n
		return
		
		; Bold an entire line.
		^+b::
			Send, ^a ; Select all (gets whole line/paragraph)
			Send, ^b
			Send, {Right} ; Put cursor at end of line
		return
		
		; Make ^7 do the same tag as ^6.
		^7::^6
		
		; Clean up a table from an EMC2 web page
		^+f::
			; Unhide table borders
			Send, {AppsKey} ; Open right-click menu
			Send, a         ; Table menu
			Send, h         ; (Un)hide borders
			Send, {Enter}   ; Multiple with h, so enter to submit it
			
			; Normalize text, indent table (table stays selected through all of these)
			Send, ^{a 4}    ; Select the whole table
			Send, ^+n       ; Normal text (get rid of underlines, text colors, etc.)
			Send, {Tab}     ; Indent the table once
			
			; Remove shading
			Send, {AppsKey} ; Open right-click menu
			Send, a         ; Table menu
			Send, {Up 5}    ; Shading option
			Send, {Right}   ; Open
			Send, n         ; No color
		return
	}
	
	^s::
		escapeOneNotePastePopup()
		Send, +{F9} ; Sync This Notebook Now
	return
	^+s::
		escapeOneNotePastePopup()
		Send, {F9} ; Sync All Notebooks Now
	return
	
	; Copy link to page.
	!c::
		copyOneNoteLink() {
			clipboard := "" ; Clear the clipboard so we can tell when we get the new link.
			
			; Get the link to the current paragraph.
			Send, +{F10}
			Sleep, 100
			Send, p
			Sleep, 500
			
			; If the special paste menu item was there (where the only option is "Paste (P)"), the menu is still open (because 2 "p" items) - get to the next one and actually submit it.
			if(WinActive("ahk_class Net UI Tool Window"))
				Send, p{Enter}
			
			ClipWait, 2 ; Wait up to 2s for the link to appear on the clipboard
			if(ErrorLevel = 1) { ; Timed out, didn't get a link.
				Toast.showMedium("No link found on clipboard")
				return
			}
			
			; Trim off the paragraph-specific part.
			copiedLink := RegExReplace(clipboard, "&object-id.*")
			
			; If there are two links involved (seems to happen with free version of OneNote), keep only the "onenote:" one (second line).
			if(stringContains(copiedLink, "`n")) {
				linkAry := StrSplit(copiedLink, "`n")
				For i,link in linkAry {
					if(stringContains(link, "onenote:"))
						linkToUse := link
				}
			} else {
				linkToUse := copiedLink
			}
			
			setClipboardAndToast(linkToUse, "link")
		}
	
	; Make a copy of the current page in the Do section.
	^+m::
		copyOneNoteDoPage() {
			; Change the page color before we leave, so it's noticeable if I end up there.
			Send, !w
			Send, pc
			Send, {Enter}
			
			Send, ^!m                  ; Move or copy page
			WinWaitActive, Move or Copy Pages
			Sleep, 500                 ; Wait a half second for the popup to be input-ready
			Send, {Down 5}             ; Select first section from first notebook (bypassing "Recent picks" section)
			Send, !c                   ; Copy button
			WinWaitClose, Move or Copy Pages
			
			; Wait for new page to appear.
			; Give the user a chance to wait a little longer before continuing
			; (for when OneNote takes a while to actually make the new page).
			t := new Toast()
			t.show()
			Loop {
				t.setText("Waiting for 2s, press space to keep waiting..." getDots(A_Index - 1))
				Input("T1", "{Esc}{Enter}{Space}") ; Wait for 1 second (exit immediately if Escape/Enter/Space is pressed)
				endKey := removeStringFromStart(ErrorLevel, "EndKey:")
				if(endKey = "Space")
					Continue
				
				; Break out immediately if enter/escape were pressed.
				if(endKey = "Enter" || endKey = "Escape")
					Break
				
				t.setText("Waiting for 1s, press space to keep waiting..." getDots(A_Index - 1))
				Input("T1", "{Esc}{Enter}{Space}") ; Wait for 1 second (exit immediately if Escape/Enter/Space is pressed)
				endKey := removeStringFromStart(ErrorLevel, "EndKey:")
				if(endKey = "Space")
					Continue
				
				Break
			}
			t.close()
			
			; Quit without doing anything else if they hit escape
			if(endKey = "Escape")
				return
			
			Send, ^{PgDn}              ; Switch to (presumably) new page
			Send, !3                   ; Demote Subpage (Make Subpage)
			
			; Make the current page have no background color.
			Send, !w
			Send, pc
			Send, n
			
			; Update title
			Send, ^+t                       ; Select title (to replace with new day/date)
			Sleep, 1000                     ; Wait for selection to take
			Send, % getOneNoteDoPageTitle() ; Send title
			Send, ^+t                       ; Select title again in case you want a different date.
		}
	
	; Insert a contact comment.
	^+8::
		insertOneNoteContactComment() {
			date := FormatTime(, "MM/yy")
			SendRaw, % "*" MainConfig.getPrivate("INITIALS") " " date
		}
	
	!+#n::
		linkOneNoteSpecificsSectionTitle() {
			waitForHotkeyRelease()
			
			Send, {Home}
			Send, ^a ; Select all, selects full line
			lineText := getSelectedText()
			
			linkText := getStringAfterStr(lineText, " - ")
			recordText := getStringBeforeStr(linkText, " (")
			editText := getStringBetweenStr(linkText, "(", ")")
			
			infoAry := extractEMC2ObjectInfo(recordText)
			ini := infoAry["INI"]
			id  := infoAry["ID"]
			; DEBUG.popup("Line",lineText, "Record text",recordText, "Edit text",editText, "infoAry",infoAry, "INI",ini, "ID",id)
			
			selectTextWithinSelection(recordText)
			webURL := buildEMC2Link(ini, id, "WEB")
			linkSelectedText(webURL)
			
			; Re-select whole line so we can use selectTextWithinSelection()
			Send, {Home}
			Send, ^a
			
			selectTextWithinSelection(editText)
			editURL := buildEMC2Link(ini, id, "EDIT")
			linkSelectedText(editURL)
		}
	
	:*:.todosat::
		sendUsualToDoSat() {
			lines := []
			lines.push({TEXT:"Pull to-dos from specific sections below"})
			lines.push({TEXT:"Dishes from week"})
			lines.push({TEXT:"Wash laundry (including Mikal's)"})
			lines.push({TEXT:"Dry laundry"})
			sendOneNoteToDoLines(lines)
		}
	
	:*:.todosun::
		sendUsualToDoSun() {
			lines := []
			lines.push({TEXT:"Pull to-dos from specific sections below"})
			lines.push({TEXT:"Review/type Ninpo notes"})
			lines.push({TEXT:"Fold laundry"})
			lines.push({TEXT:"Roomba"})
			lines.push({TEXT:"Dishes from weekend"})
			lines.push({TEXT:"Dishes from dinner"})
			lines.push({TEXT:"Trash, recycling out"})
			lines.push({TEXT:"Meal planning"})
			lines.push({TEXT:"Order/obtain groceries"})
			sendOneNoteToDoLines(lines)
		}
	
	
	; Named functions for which commands are which in the quick access toolbar.
	oneNoteNewSubpage() {
		Send, !1
	}
	oneNotePromoteSubpage() {
		Send, !2
	}
	oneNoteDemoteSubpage() {
		Send, !3
	}
	oneNoteDeletePage() {
		Send, !4
	}
	oneNoteCustomStyles() {	; Custom styles from OneTastic
		Send, !7
	}
	oneNoteCreateLinkPageSpecSection() { ; Custom OneTastic macro - create linked page in specific(s) section
		Send, !8
	}
	oneNoteCreateLinkDevPageSpecSection() { ; Custom OneTastic macro - create linked dev page in specifics section
		Send, !9
	}
	
	;---------
	; DESCRIPTION:    If the paste popup has appeared, get rid of it. Typically this is used for AHK
	;                 hotkeys that use the Control key, which sometimes causes the paste popup to
	;                 appear afterwards (if we pasted recently).
	;---------
	escapeOneNotePastePopup() {
		ControlGet, pastePopupHandle, Hwnd, , OOCWindow1, A
		if(!pastePopupHandle)
			return
		
		Send, {Space}{Backspace}
	}
	
	;---------
	; DESCRIPTION:    Select the current line and link the given EMC2 object (described by INI/ID).
	; PARAMETERS:
	;  ini (I,REQ) - INI of the object to link
	;  id  (I,REQ) - ID of the object to link
	;---------
	oneNoteLinkEMC2ObjectInLine(ini, id) {
		Send, {Home}{Shift Down}{End}{Shift Up} ; Select whole line, but avoid the extra indentation and newline that comes with ^a.
		selectTextWithinSelection(ini " " id) ; Select the INI and ID for linking
		linkSelectedText(buildEMC2Link(ini, id))
		Send, {End}
	}
	
	;---------
	; DESCRIPTION:    Figure out and return what title to use for a OneNote Do page.
	; RETURNS:        The title to use for the new OneNote Do page.
	;---------
	getOneNoteDoPageTitle() {
		startDateTime := A_Now
		
		; Do pages at work are always daily
		if(MainConfig.isMachine("EPIC_LAPTOP"))
			return FormatTime(startDateTime, "M/d`, dddd")
		
		; Otherwise, it varies by day of the week
		if(MainConfig.isMachine("HOME_DESKTOP")) {
			dayOfWeek := FormatTime(startDateTime, "Wday") ; Day of the week, 1 (Sunday) to 7 (Saturday)
			
			; Weekend pages at home are daily
			if((dayOfWeek = 1) || (dayOfWeek = 7)) ; Sunday or Saturday
				return FormatTime(startDateTime, "M/d`, dddd")
			
			; Weekdays are weekly
			; Calculate datetimes for Monday and Friday to use, even if it's not currently Monday.
			mondayDateTime := startDateTime
			mondayDateTime += -(dayOfWeek - 2), days ; If it's not Monday, get back to Monday's date.
			mondayTitle := FormatTime(mondayDateTime, "M/d`, dddd")
			
			fridayDateTime := mondayDateTime
			fridayDateTime += 4, days
			fridayTitle := FormatTime(fridayDateTime, "M/d`, dddd")
			
			; DEBUG.popup("A_Now",A_Now, "startDateTime",startDateTime, "mondayDateTime",mondayDateTime, "mondayTitle",mondayTitle, "fridayDateTime",fridayDateTime, "fridayTitle",fridayTitle)
			return mondayTitle " - " fridayTitle
		}
	}
	
	;---------
	; DESCRIPTION:    Send the given lines with a to-do tag (bound to Ctrl+1).
	; PARAMETERS:
	;  linesAry (I,REQ) - Array of lines to send, see sendOneNoteLines() for the format.
	;---------
	sendOneNoteToDoLines(linesAry) {
		Send, ^0 ; Clear current tag (so we're definitely adding the to-do tag, not checking it off)
		Send, ^1 ; To-do tag
		sendOneNoteLines(linesAry)
	}
	
	;---------
	; DESCRIPTION:    Send the lines contained in a specially-formatted array.
	; PARAMETERS:
	;  linesAry (I,REQ) - Array of lines to send, in a format which also tells us indentation:
	;                     	linesAry[lineNum, "TEXT"]     := Text to send
	;                     	                , "NUM_TABS"] := Relative indentation level (from the
	;                     	                                 starting indentation level).
	;---------
	sendOneNoteLines(linesAry) {
		currNumTabs := 0 ; Indentation level, relative to start
		For i,line in linesAry {
			if(i > 1)
				Send, {Enter}
			
			setOneNoteAlignment(forceNumber(line["NUM_TABS"]), currNumTabs)
			
			sendTextWithClipboard(line["TEXT"])
		}
	}

	;---------
	; DESCRIPTION:    Set the alignment on the current line in OneNote using Tab/Shift+Tab
	;                 keystrokes, using and updating an indicator of the current indentation
	;                 level.
	; PARAMETERS:
	;  numTabs      (I,REQ) - The number of tabs (relative to the baseline described by currNumTabs)
	;                         to set the indentation level to.
	;  currNumTabs (IO,REQ) - The current indentation level (in tabs), relative to the starting
	;                         indentation level (the level at which this would be zero).
	;---------
	setOneNoteAlignment(numTabs, ByRef currNumTabs) {
		if(currNumTabs = "")
			currNumTabs := 0
		
		; Currently not intended enough
		if(currNumTabs < numTabs) {
			neededTabs := numTabs - currNumTabs
			Send, {Tab %neededTabs%}
		
		; Currently too indented
		} else if(currNumTabs > numTabs) {
			extraTabs := currNumTabs - numTabs
			Send, +{Tab %extraTabs%}
		}
		
		; Update current state
		currNumTabs := numTabs
	}
#If
