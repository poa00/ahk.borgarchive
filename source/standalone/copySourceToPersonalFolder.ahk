#NoEnv                       ; Recommended for performance and compatibility with future AutoHotkey releases.
#SingleInstance, Force       ; Running this script while it's already running just replaces the existing instance.
SendMode, Input              ; Recommended for new scripts due to its superior speed and reliability.
#Include <includeCommon>
setCommonHotkeysType(HOTKEY_TYPE_Standalone)

sourceRoot      := MainConfig.path["AHK_ROOT"]
destinationRoot := MainConfig.path["EPIC_PERSONAL_AHK"]

confirmationMessage := "
	( LTrim
		Are you sure you want to replace the contents of this folder?
		
		Source: " sourceRoot "
		Destination: " destinationRoot "
	)"
if(!showConfirmationPopup(confirmationMessage, "Delete and replace"))
	ExitApp

; Delete existing contents of destination folder
t := new Toast("Removing existing folders and files from destination...")
t.showPersistent()
Loop, Files, %destinationRoot%\*, F ; Files
	FileDelete, % A_LoopFilePath
Loop, Files, %destinationRoot%\*, D ; Directories
	FileRemoveDir, % A_LoopFilePath, 1 ; 1-Delete recursively

; Copy over everything from source except git-related stuff.
t.setText("Copying files from source to destination...")
gitNames := [".git", ".gitignore", ".gitattributes"]
SetWorkingDir, % sourceRoot ; Set working directory and use a relative file pattern so that A_LoopFilePath has only the folders at the start for FileCopy.
Loop, Files, *, FDR ; All files and folder, recursing into folders
{
	; Don't copy over git-related files/folders.
	if(stringMatchesAnyOf(A_LoopFilePath, gitNames)) ; Check for names in full path so we catch files under ignored folders
		Continue
	
	; Create folders and copy over files
	destinationPath := destinationRoot "\" A_LoopFilePath
	if(folderExists(A_LoopFilePath))
		FileCreateDir, % destinationPath
	else
		FileCopy, % A_LoopFilePath, % destinationPath
}

t.setText("Done!")
Sleep, 2000
t.close()

ExitApp

#Include <commonHotkeys>