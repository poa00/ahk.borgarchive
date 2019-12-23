#If Config.isWindowActive("Explorer")
	; Focus address bar
	^l::Send, !d
		
	; Open "new tab" (to This PC)
	#e::
	^t::
		Run(Explorer.ThisPCFolderUUID)
	return
	
	; Copy current folder/file paths to clipboard
	!c::ClipboardLib.copyFilePathWithHotkey("!c")     ; Current file
	!#c::ClipboardLib.copyFolderPathWithHotkey("^!c") ; Current folder
	
	; Relative shortcut creation
	^+s::Explorer.createRelativeShortcut()
	
	; Hide/show hidden files
	#h::Explorer.toggleHiddenFiles()
	
	; Show TortoiseSVN/TortoiseGit log for current selection (both have an "l" hotkey in the
	; right-click menu, and appear only when the item is in that type of repo)
	!l::
		HotkeyLib.waitForRelease()
		Send, {AppsKey}
		Send, l
	return
#If

class Explorer {
	; #PUBLIC#
	
	static ThisPCFolderUUID := "::{20d04fe0-3aea-1069-a2d8-08002b30309d}"
	
	
	; #INTERNAL#
	
	;---------
	; DESCRIPTION:    Toggle whether hidden files are visible in Explorer or not.
	; NOTES:          Inspired by http://www.autohotkey.com/forum/post-342375.html#342375
	;---------
	toggleHiddenFiles() {
		; Get current state and pick the opposite to use now.
		currentState := RegRead(Explorer.ShowHiddenRegKeyName, Explorer.ShowHiddenRegValueName)
		if(currentState = 2) {
			new Toast("Showing hidden files...").showMedium()
			newValue := 1 ; Visible
		} else {
			new Toast("Hiding hidden files...").showMedium()
			newValue := 2 ; Hidden
		}
		
		; Set registry key for whether to show hidden files and refresh to apply.
		RegWrite, REG_DWORD, % Explorer.ShowHiddenRegKeyName, % Explorer.ShowHiddenRegValueName, % newValue
		Send, {F5}
	}
	
	
	createRelativeShortcut() {
		; GDB TODO should we have constants or functions or something for getting the current file/folder so it's easier to use in code here?
	}
	
	
	; #PRIVATE#
	
	static ShowHiddenRegKeyName := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
	static ShowHiddenRegValueName := "Hidden"
	; #END#
}
