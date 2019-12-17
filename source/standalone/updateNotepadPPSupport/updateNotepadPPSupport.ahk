#NoEnv                       ; Recommended for performance and compatibility with future AutoHotkey releases.
#SingleInstance, Force       ; Running this script while it's already running just replaces the existing instance.
SendMode, Input              ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir, %A_ScriptDir% ; Ensures a consistent starting directory.

#Include <includeCommon>
CommonHotkeys.Init(CommonHotkeys.ScriptType_Standalone)

#Include autoCompleteClass.ahk
#Include autoCompleteMember.ahk

; Constants we use to pick apart scripts for their component parts.
global Header_StartEnd            := ";---------"
global ScopeStart_Public          := "; #PUBLIC#"
global ScopeStart_NonPublicScopes := ["; #INTERNAL#", "; #PRIVATE#", "; #DEBUG#"]
global ScopeEnd                   := "; #END#"

; [[File paths]] --=
path_CompletionTemplate_AHK := Config.path["AHK_TEMPLATE"] "\notepadPP_AutoComplete_AHK.xml"
path_CompletionTemplate_TL  := Config.path["AHK_TEMPLATE"] "\notepadPP_AutoComplete_TL.xml"
path_CompletionOutput_AHK   := Config.path["AHK_OUTPUT"]   "\notepadPP_AutoComplete_AHK.xml"
path_CompletionOutput_TL    := Config.path["AHK_OUTPUT"]   "\notepadPP_AutoComplete_TL.xml"

path_SyntaxTemplate_AHK := Config.path["AHK_TEMPLATE"] "\notepadPP_SyntaxHighlighting_AHK.xml"
path_SyntaxTemplate_TL  := Config.path["AHK_TEMPLATE"] "\notepadPP_SyntaxHighlighting_TL.xml"
path_SyntaxOutput_AHK   := Config.path["AHK_OUTPUT"]   "\notepadPP_SyntaxHighlighting_AHK.xml"
path_SyntaxOutput_TL    := Config.path["AHK_OUTPUT"]   "\notepadPP_SyntaxHighlighting_TL.xml"

path_SyntaxTemplate_Base  := Config.path["AHK_TEMPLATE"]  "\notepadPP_SyntaxHighlighting_Base.xml" ; Base XML in case the file doesn't exist yet
path_CompletionActive_AHK := Config.path["PROGRAM_FILES"] "\Notepad++\autoCompletion\AutoHotkey.xml"
path_CompletionActive_TL  := Config.path["PROGRAM_FILES"] "\Notepad++\autoCompletion\TableList.xml"
path_SyntaxActive         := Config.path["USER_APPDATA"]  "\Notepad++\userDefineLang.xml" ; This file is for all user-defined languages


; [[ Auto-complete ]] ---
; AHK: use documentation read from various script files
autoCompleteClasses := getAutoCompleteClasses()
xmlLines := FileLib.fileLinesToArray(path_CompletionTemplate_AHK)
updateAutoCompleteXML(xmlLines, autoCompleteClasses)

newXML := xmlLines.join("`n")
FileLib.replaceFileWithString(path_CompletionOutput_AHK, newXML)
FileLib.replaceFileWithString(path_CompletionActive_AHK, newXML)


; GDB TODO next plans:
;	- Can we just do one read-in of various scripts for both AHK and TL languages?
;		- Still need folder-level divisions for class groups for syntax highlighting
;			- Unless we want to add script-level headers to cover that?
;		- What level would we need to store/track things at?
;			- Auto-complete really only needs member level when we're done, but we do need class level for post-processing (inheritance) + syntax highlighting
;			- Would class-level, but with a "none"/"" or similar class work?
;				- Could cause issues for sorting - we'd need to get down to the member level before sorting for auto-complete updates.
;					- Or would it matter? We don't have anything for AHK that has no class, and nothing with a class for TL, right?
;			- Potential structure: Language > Class > Member
;				- Class members don't really need to be stored with a dot - just store them numerically and we'll sort everything when we output (maybe triggered by generateXML, even?)
;				- Examples:
;					AHK > ActionObjectPath > copyLink
;					TL > "" > WindowTitle
;	- Extra "@" returns prefix/value should probably live at the member level - maybe an addition to the doc header? @DOC-RETURNS: or similar?
;	- Should the TL format call-out really just be at the member level as well, instead of the [[STUB]] stuff?
;		- LANGUAGE, @LANGUAGE, DOC-LANGUAGE, @DOC-LANG?






; TL: use documentation from specific scripts
; xmlLines := FileLib.fileLinesToArray(path_CompletionTemplate_TL)


membersByDotName := {}
addTLMembersFromStubs(membersByDotName, Config.path["AHK_SOURCE"] "\common\class\Selector.ahk", "@")
addTLMembersFromStubs(membersByDotName, Config.path["AHK_SOURCE"] "\common\class\TableListMod.ahk")


; Debug.popup("membersByDotName",membersByDotName)

sortedMembers := []

; Get the names and sort them
For dotName,_ in membersByDotName
	memberNames := memberNames.appendPiece(dotName.removeFromStart("."), "`n")
Sort, memberNames, F keywordSortsAfter
For _,name in memberNames.split("`n")
	sortedMembers.push(membersByDotName["." name])

; Debug.popup("sortedMembers",sortedMembers)

keywordsXML := ""
For _,member in sortedMembers
	keywordsXML := keywordsXML.appendPiece(member.generateXML(), "`n")

templateXML := FileRead(path_CompletionTemplate_TL)
newXML := templateXML.replace("{{KEYWORDS}}", keywordsXML)

; Debug.popup("keywordsXML",keywordsXML, "newXML",newXML)
; clipboard := newXML



FileLib.replaceFileWithString(path_CompletionOutput_TL, newXML)
FileLib.replaceFileWithString(path_CompletionActive_TL, newXML)

t := new Toast("Updated both versions of the auto-complete file").show()


; [[ Syntax highlighting ]] ---
; AHK: we can get the class groups we need from the auto complete classes we built above
xmlSyntax_AHK := FileRead(path_SyntaxTemplate_AHK)
updateAHKSyntaxXML(xmlSyntax_AHK, autoCompleteClasses)
FileLib.replaceFileWithString(path_SyntaxOutput_AHK, xmlSyntax_AHK)

; TL: the template file already has exactly what we want to plug in, no processing needed.
xmlSyntax_TL := FileRead(path_SyntaxTemplate_TL)
FileLib.replaceFileWithString(path_SyntaxOutput_TL, xmlSyntax_TL)

; Get the XML to update - from either an existing file or the base template.
if(FileExist(path_SyntaxActive))
	activeSyntaxXML := FileRead(path_SyntaxActive)
else
	activeSyntaxXML := FileRead(path_SyntaxTemplate_Base)

; Plug each language into its spot in the XML
updateLangInSyntaxXML(activeSyntaxXML, "AutoHotkey", xmlSyntax_AHK)
updateLangInSyntaxXML(activeSyntaxXML, "TableList",  xmlSyntax_TL)
FileLib.replaceFileWithString(path_SyntaxActive, activeSyntaxXML)
; =--


t.setText("Updated syntax highlighting file for Notepad++ (requires restart)").blockingOn().showMedium()

ExitApp


;---------
; DESCRIPTION:    Get an array of classes that we care about for auto-completion purposes.
; RETURNS:        An array of AutoCompleteClass instances, in auto-complete sorted order.
;---------
getAutoCompleteClasses() {
	classes := {}
	
	; Read in and extract all classes from scripts in these folders
	addClassesFromFolder(classes, Config.path["AHK_SOURCE"] "\common\base",   "BASE_CLASSES")
	addClassesFromFolder(classes, Config.path["AHK_SOURCE"] "\common\class",  "INSTANCE_CLASSES")
	addClassesFromFolder(classes, Config.path["AHK_SOURCE"] "\common\lib",    "LIB_CLASSES")
	addClassesFromFolder(classes, Config.path["AHK_SOURCE"] "\common\static", "STATIC_CLASSES")
	addClassesFromFolder(classes, Config.path["AHK_SOURCE"] "\program",       "PROGRAM_CLASSES", "[Requires program includes]") ; Include program-specific classes, but with a returns prefix.
	
	; Remove empty classes and handle inheritance.
	classesToDelete := []
	For className,classObj in classes {
		; Mark any classes with no members for deletion
		if(classObj.members.count() = 0)
			classesToDelete.push(className)
		
		; Handle inheritance: add any parent members (only 1 layer deep) into this class
		if(classObj.parentName != "") {
			For _,member in classes[classObj.parentName].members
				classObj.addMemberIfNew(member)
		}
	}
	For _,className in classesToDelete
		classes.Delete(className)
	
	; Sort properly (underscores sort last)
	return getAutoCompleteSortedClasses(classes)
}

;---------
; DESCRIPTION:    Add all classes from the scripts in the given folder to the classes object.
; PARAMETERS:
;  classes      (IO,REQ) - The object to add the class objects to, indexed by class name.
;  folderPath    (I,REQ) - The full path to the folder to read from.
;  classGroup    (I,REQ) - Which "group" the classes in this folder should have - this determines
;                          how they get syntax-highlighted.
;  returnsPrefix (I,OPT) - The prefix to add to the auto-complete return value of all functions in
;                          all classes in this folder.
;---------
addClassesFromFolder(ByRef classes, folderPath, classGroup, returnsPrefix := "") {
	; Loop over all scripts in folder to find classes
	Loop, Files, %folderPath%\*.ahk, RF ; [R]ecursive, [F]iles (not [D]irectories)
	{
		linesAry := FileLib.fileLinesToArray(A_LoopFileLongPath, true)
		
		ln := 0 ; Lines start at 1 (and the loop starts by increasing the index).
		while(ln < linesAry.count()) {
			line := linesAry.next(ln)
			
			; Block of documentation - read the whole thing in and create a member.
			if(line = Header_StartEnd) {
				; Store the full header in an array
				headerLines := [line]
				Loop {
					line := linesAry.next(ln)
					headerLines.push(line)
					
					if(line = Header_StartEnd)
						Break
				}
				
				; Get the definition line (first line after the header), too.
				defLine := linesAry.next(ln)
				
				; Feed the data to a new member object and add that to our current class object.
				member := new AutoCompleteMember(defLine, headerLines, returnsPrefix)
				classObj.addMember(member)
				
				Continue
			}
			
			; Block of private/debug scope - ignore everything up until we hit a public/end of scope.
			if(ScopeStart_NonPublicScopes.contains(line)) {
				while(line != ScopeStart_Public && line != ScopeEnd) {
					line := linesAry.next(ln)
				}
				
				Continue
			}
			
			; Class declaration
			if(line.startsWith("class ") && line.endsWith(" {") && line != "class {") {
				classObj := new AutoCompleteClass(line, classGroup)
				classes[classObj.name] := classObj ; Point to classObj (which is what we'll actually be updating) from classes object
				
				Continue
			}
		}
	}
	
	return classes
}

;---------
; DESCRIPTION:    Convert the className-indexed associative array into a normal array, sorted in
;                 auto-complete order.
; PARAMETERS:
;  functionsByClassName (I,REQ) - The associative array of AutoCompleteClass instances. Format:
;                                  functionsByClassName[className] := autoCompleteClassInstance
; RETURNS:        A numeric array, sorted in auto-complete order
; NOTES:          Auto-complete order is case-insensitive alphabetical order, but where underscore
;                 sorts after everything else.
;---------
getAutoCompleteSortedClasses(functionsByClassName) {
	classes := []
	
	; Get the names and sort them
	classNames := functionsByClassName.toKeysArray().join("`n")
	Sort, classNames, F keywordSortsAfter
	
	; Populate new array in correct order
	For _,className in classNames.split("`n")
		classes.push(functionsByClassName[className])
	
	return classes
}

;---------
; DESCRIPTION:    Update the given array of XML lines using the given array of class information.
; PARAMETERS:
;  xmlLines (IO,REQ) - An array of XML lines to update.
;  classes   (I,REQ) - A numeric array of AutoCompleteClass instances. Must be in auto-complete order.
;---------
updateAutoCompleteXML(ByRef xmlLines, classes) {
	; Loop through our sorted classes, inserting their XML in the right place as we go.
	commentOn := false
	ln := 0 ; Lines start at 1 (and the loop starts by increasing the index).
	For _,classObj in classes { ; Sorted class objects
		while(ln < xmlLines.count()) { ; Loop over lines of XML
			line := xmlLines.next(ln).withoutWhitespace()
			
			; Ignore comment blocks
			if(line.startsWith("<!--")) {
				commentOn := true
			}
			if(line.endsWith("-->")) {
				commentOn := false
				Continue
			}
			if(commentOn)
				Continue
			
			; Ignore anything that's not a keyword line
			if(!line.startsWith("<KeyWord name="""))
				Continue
			
			; If the class name sorts after the current keyword, we haven't gone far enough yet.
			keywordName := line.firstBetweenStrings("<KeyWord name=""", """")
			if(keywordSortsAfter(classObj.name, keywordName) > 0)
				Continue
			
			; We've found the right spot - insert our XML.
			classXML := classObj.generateXML()
			xmlLines.InsertAt(ln, classXML) ; This technically puts a bunch of lines of text into one "line", but we're never going to insert something in the middle of the class, so that should be fine.
			ln-- ; Take a step backwards so we check the same line we just checked (which is just after the class XML we just inserted) against the next class.
			Break ; Move onto the next class.
		}
	} ; This will technically fail to add anything that sorts to the very end, but I don't think I'm ever going to create a new class that starts with __ so we should be fine.
}

;---------
; DESCRIPTION:    Comparison function for sorting in auto-complete order.
; PARAMETERS:
;  word1 (I,REQ) - The first word to compare
;  word2 (I,REQ) - The second word to compare
; RETURNS:        1 - word1 > word2
;                 0 - word1 = word2
;                -1 - word1 < word2
; NOTES:          Auto-complete order is case-insensitive alphabetical order, but with underscores
;                 sorting after everything else.
;---------
keywordSortsAfter(word1, word2) {
	Loop, Parse, word1
	{
		c1 := A_LoopField
		c2 := word2.charAt(A_Index)
		
		; Same character - keep going
		if(c1 = c2)
			Continue
		
		; Shorter name goes first
		if(c2 = "")
			return 1
		
		; Underscore should sort after everything else
		if(c1 = "_")
			return 1
		if(c2 = "_")
			return -1
		
		; Otherwise we can use normal character comparison
		if(c1 < c2)
			return -1
		if(c1 > c2)
			return 1
	}
	
	; If word1 is shorter, it should come first.
	if(word2.length() > word1.length())
		return -1
	
	return 0
}

; GDB TODO
addTLMembersFromStubs(ByRef membersByDotName, path, returnsPrefix := "") {
	stubsStart := "[[TABLELIST STUBS]]"
	stubsEnd := "[[END TABLELIST STUBS]]"
	
	stubLines := FileRead(path).allBetweenStrings(stubsStart, stubsEnd)
	linesAry := stubLines.split("`r`n")
	linesAry.removeAt(1) ; Drop the remainder of the opening line
	linesAry.pop() ; Drop the leftovers from the last line

	; Debug.popup("linesAry",linesAry)

	ln := 0 ; Lines start at 1 (and the loop starts by increasing the index).
	while(ln < linesAry.count()) {
		line := linesAry.next(ln).withoutWhitespace()
		
		; Debug.popup("line","z" line "z", "Header_StartEnd","z" Header_StartEnd "z", "line = Header_StartEnd",(line = Header_StartEnd))
		
		; Block of documentation - read the whole thing in and create a member.
		if(line = Header_StartEnd) {
			; Debug.popup("line",, "line",line)
			; Store the full header in an array
			headerLines := [line]
			Loop {
				line := linesAry.next(ln).withoutWhitespace()
				headerLines.push(line)
				
				if(line = Header_StartEnd)
					Break
			}
			
			; Get the definition line (first line after the header), too.
			defLine := linesAry.next(ln)
			
			; Feed the data to a new member object and add that to our current class object.
			member := new AutoCompleteMember(defLine, headerLines, returnsPrefix)
			membersByDotName["." member.name] := member
			
			Continue
		}
	}
}

;---------
; DESCRIPTION:    Update the given AHK syntax highlighting XML with groups of space-separated class names.
; PARAMETERS:
;  syntaxXML           (IO,REQ) - The XML to update.
;  autoCompleteClasses  (I,REQ) - The array of AutoCompleteClass instances from getAutoCompleteClasses().
;---------
updateAHKSyntaxXML(ByRef syntaxXML, autoCompleteClasses) {
	; Generate the class groups we need from our auto-complete classes
	classGroups := {}
	For _,classObj in autoCompleteClasses {
		names := classGroups[classObj.group]
		names := names.appendPiece(classObj.name, " ")
		classGroups[classObj.group] := names
	}
	
	; Update all replacement markers with the groups
	For groupName,classNames in classGroups {
		groupTextToReplace := "{{" groupName "}}"
		syntaxXML := syntaxXML.replace(groupTextToReplace, classNames)
	}
}

;---------
; DESCRIPTION:    Update the given XML with the given language-specific XML.
; PARAMETERS:
;  activeSyntaxXML (IO,REQ) - XML to update with the language.
;  langName         (I,REQ) - The name of the language, should be the name from the <UserLang> tag that we'll replace.
;  langFullXML      (I,REQ) - The full, importable XML for the lanaguage (including the <NotepadPlusPlus> tag)
;---------
updateLangInSyntaxXML(ByRef activeSyntaxXML, langName, langFullXML) {
	; We only need the chunk of XML specific to the language (including the rest of the opening <UserLang> tag, which has file extensions and such)
	langXML := langFullXML.allBetweenStrings("<UserLang name=""" langName """", "</UserLang>")
	
	; Replace the same thing in the active XML.
	xmlToReplace := activeSyntaxXML.firstBetweenStrings("<UserLang name=""" langName """", "</UserLang>")
	activeSyntaxXML := activeSyntaxXML.replace(xmlToReplace, langXML)
}
