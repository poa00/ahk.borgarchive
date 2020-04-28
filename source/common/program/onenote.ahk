#Include oneNoteTodoPage.ahk
class OneNote {
	; #PUBLIC#
	
	;---------
	; DESCRIPTION:    Select the current line and link the given EMC2 object (described by INI/ID).
	; PARAMETERS:
	;  ini (I,REQ) - INI of the object to link
	;  id  (I,REQ) - ID of the object to link
	;---------
	linkEMC2ObjectInLine(ini, id) {
		SelectLib.selectCurrentLine() ; Select whole line, but avoid the extra indentation and newline that comes with ^a.
		SelectLib.selectTextWithinSelection(ini " " id) ; Select the INI and ID for linking
		
		new ActionObjectEMC2(id, ini).linkSelectedTextWeb("Failed to link EMC2 object text")
		
		Send, {End}
	}
	
	
	; #INTERNAL#
	
	;---------
	; DESCRIPTION:    Scroll left/right in the OneNote window (assuming it's under the mouse)
	;---------
	scrollLeft() {
		MouseGetPos, , , winId, controlId, 1
		SendMessage, MicrosoftLib.Message_HorizScroll, MicrosoftLib.ScrollBar_Left, , % controlId, % "ahk_id " winId
	}
	scrollRight() {
		MouseGetPos, , , winId, controlId, 1
		SendMessage, MicrosoftLib.Message_HorizScroll, MicrosoftLib.ScrollBar_Right, , % controlId, % "ahk_id " winId
	}
	
	;---------
	; DESCRIPTION:    If the paste popup has appeared, get rid of it. Typically this is used for AHK
	;                 hotkeys that use the Control key, which sometimes causes the paste popup to
	;                 appear afterwards (if we pasted recently).
	;---------
	escapePastePopup() {
		if(!ControlGet("Hwnd", , "OOCWindow1", A))
			return
		
		Send, {Space}{Backspace}
	}
	
	;---------
	; DESCRIPTION:    Select the whole line in OneNote, taking into account that it might already be selected.
	;---------
	selectLine() {
		Send, {Home} ; Make sure the line isn't already selected, otherwise we select the whole parent.
		Send, ^a     ; Select all - gets entire line, including newline at end.
	}
	
	;---------
	; DESCRIPTION:    Named commands for hard-coded references to quick access toolbar items in OneNote.
	;---------
	newSubpage() {
		Send, !1
	}
	promoteSubpage() {
		Send, !2
	}
	makeSubpage() {
		Send, !3
	}
	deletePage() {
		Send, !4
	}
	addMeetingNotes() {
		Send, !5
	}
	zoomTo100Percent() {
		Send, !6
	}
	customStyles() {	; Custom styles from OneTastic
		Send, !7
	}
	createLinkPageSpecSection() { ; Custom OneTastic macro - create linked page in specific(s) section
		Send, !8
	}
	createLinkDevPageSpecSection() { ; Custom OneTastic macro - create linked dev page in specifics section
		Send, !9
	}
	addSubLinesToSelectedLines() { ; Custom OneTastic macro - add sub-lines to selected lines
		Send, !0
	}
	
	;---------
	; DESCRIPTION:    Confirm with the user that they want to delete the current page, then do so.
	;---------
	deletePageWithConfirm() {
		; Confirmation to avoid accidental page deletion
		if(GuiLib.showConfirmationPopup("Are you sure you want to delete this page?", "Delete page?"))
			OneNote.deletePage()
	}
	
	;---------
	; DESCRIPTION:    Format the selected text as code using OneTastic custom styles.
	;---------
	applyCodeStyle() {
		OneNote.customStyles()
		Send, {Enter}
	}
	
	;---------
	; DESCRIPTION:    Put a link to the current page on the clipboard.
	;---------
	copyLinkToCurrentPage() {
		ClipboardLib.setAndToast(OneNote.getLinkToCurrentPage(), "link")
	}
	
	;---------
	; DESCRIPTION:    Copy the current page's title and link to the clipboard.
	;---------
	copyTitleLinkToCurrentPage() {
		link := OneNote.getLinkToCurrentPage()
		title := OneNote.getPageTitle()
		
		ClipboardLib.setAndToast(title "`n" link, "page title + link")
	}
	
	;---------
	; DESCRIPTION:    Copy the link for the text that's under the mouse (if any) to the clipboard.
	;---------
	copyLinkUnderMouse() {
		copyLinkFunction := ObjBindMethod(OneNote, "doCopyLinkUnderMouse")
		if(!ClipboardLib.copyWithFunction(copyLinkFunction)) {
			; If we clicked on something other than a link, the i option is "Link..." which will open the Link popup. Close it if it appeared.
			if(WinActive("Link ahk_class NUIDialog ahk_exe ONENOTE.EXE"))
				Send, {Esc}
		}
		
		ClipboardLib.toastNewValue("link target")
	}
	
	;---------
	; DESCRIPTION:    Remove the link from the text that's under the mouse (if any).
	;---------
	removeLinkUnderMouse() {
		Click, Right
		Sleep, 100 ; Wait for menu to appear
		Send, r    ; Remove link
		
		; Go ahead and finish if the right-click menu is gone, we're done.
		if(!WinActive(OneNote.TitleString_RightClickMenu))
			return
		
		; If the right click menu is still open (probably because it wasn't a link and therefore
		; there was no "r" option), give it a tick to close on its own, then close it.
		Sleep, 100
		if(WinActive(OneNote.TitleString_RightClickMenu))
			Send, {Esc}
	}
	
	;---------
	; DESCRIPTION:    The dev structure in question has section headers with an INI/ID, and a space
	;                 for an edit link. Add links to both the INI/ID (web) and the edit spot.
	;---------
	linkDevStructureSectionTitle() {
		HotkeyLib.waitForRelease()
		
		OneNote.selectLine()
		lineText := SelectLib.getText()
		if(lineText = "" || lineText = "`r`n") ; Selecting the whole line in OneNote gets us the newline, so treat just a newline as an empty case as well.
			return
		
		linkText   := lineText.afterString(" - ")
		recordText := linkText.beforeString(" (")
		editText   := linkText.firstBetweenStrings("(", ")")
		
		; If there's not an ID in place yet, update the recordText using the ID (we're assuming is) on the clipboard.
		if(recordText.endsWith(" *")) {
			newId := clipboard.clean()
			if(!newId.sub(2).isNum()) { ; Safety check: ID should be numeric after first character (for SU DLGs)
				new ErrorToast("No record ID found", "Neither the line text nor the clipboard contained a valid record ID").showMedium()
				return
			}
			
			SelectLib.selectTextWithinSelection(recordText) ; Whole line is already selected so we can use this
			recordText := recordText.removeFromEnd("*") newId
			Send, % recordText
			OneNote.selectLine() ; Re-select whole line so we can use SelectLib.selectTextWithinSelection() below
		}
		
		ao := new ActionObjectEMC2(recordText)
		; Debug.popup("Line",lineText, "Record text",recordText, "Edit text",editText, "ao.ini",ao.ini, "ao.id",ao.id)
		
		SelectLib.selectTextWithinSelection(recordText)
		ao.linkSelectedTextWeb("Failed to add EMC2 object web link")
		
		OneNote.selectLine() ; Re-select whole line so we can use SelectLib.selectTextWithinSelection() again
		
		SelectLib.selectTextWithinSelection(editText)
		ao.linkSelectedTextEdit("Failed to add EMC2 object edit link")
	}
	
	
	; #PRIVATE#
	
	static TitleString_RightClickMenu := "ahk_class Net UI Tool Window"
	
	;---------
	; DESCRIPTION:    Get a link to the current page
	; RETURNS:        The simple link to the current page, via OneNote (not online link).
	;---------
	getLinkToCurrentPage() {
		copiedLink := OneNote.getLinkToCurrentParagraph()
		if(copiedLink = "") {
			new ErrorToast("Could not get paragraph link on clipboard").showMedium()
			return
		}
		
		; Trim off the paragraph-specific part.
		copiedLink := copiedLink.removeRegEx("&object-id.*")
		
		; If there are two links involved (seems to happen with free version of OneNote), keep only the "onenote:" one (second line).
		if(copiedLink.contains("`n")) {
			linkAry := copiedLink.split("`n")
			For i,link in linkAry {
				if(link.contains("onenote:"))
					linkToUse := link
			}
		} else {
			linkToUse := copiedLink
		}
		
		return linkToUse
	}
	
	;---------
	; DESCRIPTION:    Get the title of the current page.
	; RETURNS:        The title of the current page.
	;---------
	getPageTitle() {
		Send, ^+a                             ; Select page tab
		pageContent := SelectLib.getText() ; Copy entire page contents
		Send, {Escape}                        ; Get back to the editing area
		return pageContent.firstLine()        ; Title is the first line of the content
	}
	
	;---------
	; DESCRIPTION:    Get the link to the current paragraph to the clipboard.
	; RETURNS:        The link to the current paragraph.
	;---------
	getLinkToCurrentParagraph() {
		copyFunction := ObjBindMethod(OneNote, "copyLinkToCurrentParagraph")
		return ClipboardLib.getWithFunction(copyFunction)
	}
	
	;---------
	; DESCRIPTION:    Copy a link to the current paragraph to the clipboard.
	;---------
	copyLinkToCurrentParagraph() {
		Send, +{F10}
		WinWaitActive, % OneNote.TitleString_RightClickMenu
		Send, p
		WinWaitNotActive, % OneNote.TitleString_RightClickMenu, , 0.5
		
		; Special handling: if we didn't get anything, it might be because the special paste menu item was there (where the only option is "Paste (P)").
		; If that's the case, try getting to the second "p" option and submit it.
		if(WinActive(OneNote.TitleString_RightClickMenu))
			Send, p{Enter}
	}
	
	;---------
	; DESCRIPTION:    Copy the link target under the mouse to the clipboard.
	;---------
	doCopyLinkUnderMouse() {
		Click, Right
		WinWaitActive, % OneNote.TitleString_RightClickMenu
		Send, i ; Copy Link
	}
	
	;---------
	; DESCRIPTION:    Insert a blank line on the current line and put the cursor on it.
	;---------
	insertBlankLine() {
		Send, {Home}  ; Get to start of line
		Send, {Enter} ; New line
		Send, {Left}  ; Get back up to new blank line
	}
	; #END#
}