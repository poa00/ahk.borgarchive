#NoEnv                       ; Recommended for performance and compatibility with future AutoHotkey releases.
#SingleInstance, Force       ; Running this script while it's already running just replaces the existing instance.
SendMode, Input              ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir, %A_ScriptDir% ; Ensures a consistent starting directory.

#Include <includeCommon>
CommonHotkeys.Init(CommonHotkeys.ScriptType_Standalone)

; Constants we use to pick apart scripts for their component parts.
global Header_StartEnd            := ";---------"
global ScopeStart_Public          := "; #PUBLIC#"
global ScopeStart_NonPublicScopes := ["; #INTERNAL#", "; #PRIVATE#", "; #DEBUG#"]
global ScopeEnd                   := "; #END#"

path_CompletionTemplate := Config.path["AHK_TEMPLATE"] "\notepadPP_AutoComplete.xml"
path_SyntaxTemplate     := Config.path["AHK_TEMPLATE"] "\notepadPP_SyntaxHighlighting.xml"
path_CompletionOutput   := Config.path["AHK_OUTPUT"]   "\notepadPP_AutoComplete.xml"
path_SyntaxOutput       := Config.path["AHK_OUTPUT"]   "\notepadPP_SyntaxHighlighting.xml"
path_CompletionActive   := Config.path["PROGRAM_FILES"] "\Notepad++\autoCompletion\AutoHotkey.xml"
path_SyntaxActive       := Config.path["USER_APPDATA"]  "\Notepad++\userDefineLang.xml"

; [[ Auto-complete ]]
autoCompleteClasses := getAutoCompleteClasses()
xmlLines := FileLib.fileLinesToArray(path_CompletionTemplate)
updateAutoCompleteXML(xmlLines, autoCompleteClasses)

newXML := xmlLines.join("`n")
FileLib.replaceFileWithString(path_CompletionActive, newXML)
FileLib.replaceFileWithString(path_CompletionOutput, newXML)

t := new Toast("Updated both versions of the auto-complete file").show()

; [[ Syntax highlighting ]]
; We can get the class groups we need from the auto complete classes we built above
syntaxXML := FileRead(path_SyntaxTemplate)
updateSyntaxHighlightingXML(syntaxXML, autoCompleteClasses)
FileLib.replaceFileWithString(path_SyntaxOutput, syntaxXML)

; If the active file doesn't exist, just populate it with the same content.
if(!FileExist(path_SyntaxActive)) {
	FileLib.replaceFileWithString(path_SyntaxActive, syntaxXML)
} else {
	; If the active file does exist, we don't want to replace the whole thing, as there could be other
	; user-defined languages - so just replace the AHK <UserLang> tag.
	langXML := syntaxXML.allBetweenStrings("<UserLang name=""AutoHotkey""", "</UserLang>")

	activeSyntaxXML := FileRead(path_SyntaxActive)
	replaceXML := activeSyntaxXML.firstBetweenStrings("<UserLang name=""AutoHotkey""", "</UserLang>")
	activeSyntaxXML := activeSyntaxXML.replace(replaceXML, langXML)
}
FileLib.replaceFileWithString(path_SyntaxActive, activeSyntaxXML)

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
;  classes       (IO,REQ) - The object to add the class objects to, indexed by class name.
;  folderPath     (I,REQ) - The full path to the folder to read from.
;  classGroup     (I,REQ) - The class group that all of these classes should be a part of, used for
;                           syntax highlighting.
;  returnsPrefix  (I,OPT) - The prefix to add to the auto-complete return value of all functions in
;                           all classes in this folder.
;---------
addClassesFromFolder(ByRef classes, folderPath, classGroup, returnsPrefix := "") {
	newClasses := getClassesFromFolder(folderPath, classGroup, returnsPrefix)
	classes.mergeFromObject(newClasses)
}

;---------
; DESCRIPTION:    Get AutoCompleteClass objects for all classes in all scripts in the given folder.
; PARAMETERS:
;  folderPath    (I,REQ) - The full path to the folder to read from.
;  classGroup    (I,REQ) - Which "group" the classes in this folder should have - this determines
;                          how they get syntax-highlighted.
;  returnsPrefix (I,OPT) - If specified, the returns value will appear as a prefix on the return value.
; RETURNS:        An associative array of AutoCompleteClass objects, indexed by the class' names.
;---------
getClassesFromFolder(folderPath, classGroup, returnsPrefix := "") {
	classes := {}
	
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

;---------
; DESCRIPTION:    Update the given syntax highlighting XML with groups of space-separated class names.
; PARAMETERS:
;  syntaxXML           (IO,REQ) - The XML to update.
;  autoCompleteClasses  (I,REQ) - The array of AutoCompleteClass instances from getAutoCompleteClasses().
;---------
updateSyntaxHighlightingXML(ByRef syntaxXML, autoCompleteClasses) {
	; Generate the class groups we need from our auto-complete classes
	classGroups := {}
	For _,classObj in autoCompleteClasses {
		names := classGroups[classObj.group]
		names := names.appendPiece(classObj.name, " ")
		classGroups[classObj.group] := names
	}
	
	; Update all replacement markers with the groups
	For groupName,classNames in classGroups {
		groupTextToReplace := "{{REPLACE: " groupName "}}"
		syntaxXML := syntaxXML.replace(groupTextToReplace, classNames)
	}
}


; Represents an entire class that we want to add auto-complete info for.
class AutoCompleteClass {
	; #INTERNAL#
	
	name       := "" ; The class' name
	parentName := "" ; The name of the class' parent (if it extends another class)
	group      := "" ; The group (used for syntax highlighting)
	members    := {} ; {.memberName: AutoCompleteMember}
	
	;---------
	; DESCRIPTION:    Create a new class representation.
	; PARAMETERS:
	;  defLine (I,REQ) - The definition line for the class - the one that starts with "class ".
	;  group   (I,REQ) - The group this class should be part of, for syntax highlighting purposes.
	;---------
	__New(defLine, group) {
		this.name := defLine.firstBetweenStrings("class ", " ") ; Break on space instead of end bracket so we don't end up including the "extends" bit for child classes.
		if(defLine.contains(" extends "))
			this.parentName := defLine.firstBetweenStrings(" extends ", " {")
		
		this.group := group
	}
	
	;---------
	; DESCRIPTION:    Add the given member to this class.
	; PARAMETERS:
	;  member (I,REQ) - The member to add.
	;---------
	addMember(member) {
		if(member.name = "")
			return
		
		dotName := "." member.name ; The index is the name with a preceding dot - otherwise we start overwriting things like <array>.contains with this array, and that breaks stuff.
		this.members[dotName] := member
	}
	;---------
	; DESCRIPTION:    Add the given member to this class, but only if a member with the same name
	;                 doesn't already exist.
	; PARAMETERS:
	;  member (I,REQ) - The member to add.
	;---------
	addMemberIfNew(member) {
		if(member.name = "")
			return
		
		dotName := "." member.name ; The index is the name with a preceding dot - otherwise we start overwriting things like <array>.contains with this array, and that breaks stuff.
		if(this.members.HasKey(dotName))
			return
		
		this.members[dotName] := member
	}
	
	;---------
	; DESCRIPTION:    Generate the XML for this class and all of its members.
	; RETURNS:        The generated XML
	;---------
	generateXML() {
		xml := ""
		For _,member in this.members
			xml := xml.appendPiece(member.generateXML(this.name), "`n")
		return xml
	}
	
	
	; #DEBUG#
	
	getDebugTypeName() {
		return "AutoCompleteClass"
	}
	; #END#
}

; Represents a single class member that we want to add auto-complete info for.
class AutoCompleteMember {
	; #INTERNAL#
	
	name        := ""
	returns     := ""
	description := ""
	paramsAry   := []
	
	;---------
	; DESCRIPTION:    Create a new member.
	; PARAMETERS:
	;  defLine       (I,REQ) - The definition line for the member - that is, its first line
	;                          (function definition, etc.).
	;  headerLines   (I,REQ) - An array of lines making up the full header for this member.
	;  returnsPrefix (I,OPT) - If specified, the returns value will appear as a prefix on the return value.
	;---------
	__New(defLine, headerLines, returnsPrefix := "") {
		AHKCodeLib.getDefLineParts(defLine, name, paramsAry)
		this.name      := name
		this.paramsAry := paramsAry
		
		; Properties get special handling to call them out as properties (not functions), since you have to use an open paren to get the popup to display.
		this.returns := returnsPrefix
		if(!defLine.contains("("))
			this.returns := this.returns.appendPiece(this.ReturnValue_Property, " ")
		
		; The description is the actual function header, indented nicely.
		this.description := this.formatHeaderAsDescription(headerLines)
	}
	
	;---------
	; DESCRIPTION:    Generate the XML for this member.
	; PARAMETERS:
	;  className (I,REQ) - The class that this member belongs to.
	; RETURNS:        The XML for this member.
	;---------
	generateXML(className) {
		xml := this.BaseXML_Keyword
		
		xml := xml.replaceTag("FULL_NAME",   this.generateFullName(className))
		xml := xml.replaceTag("RETURNS",     this.returns)
		xml := xml.replaceTag("DESCRIPTION", this.description)
		xml := xml.replaceTag("PARAMS_XML",  this.generateParamsXML())
		
		return xml
	}
	
	
	; #PRIVATE#
	
	static ReturnValue_Property := "[Property]"
	; <PARAMS_XML> has no indent/newline so each line of the params can indent itself the same.
	; Always func="yes", because that allows us to get a popup with the info.
	static BaseXML_Keyword := "
		(
        <KeyWord name=""<FULL_NAME>"" func=""yes"">
            <Overload retVal=""<RETURNS>"" descr=""<DESCRIPTION>""><PARAMS_XML>
            </Overload>
        </KeyWord>
		)"
	static BaseXML_Param := "
		(
                <Param name=""<PARAM_NAME>"" />
		)"
	static Indent_Header := StringLib.getTabs(7) ; We can indent with tabs and it's ignored - cleaner XML and result looks the same.
	
	;---------
	; DESCRIPTION:    Turn the array of documentation lines into a single, indented, XML-safe string.
	; PARAMETERS:
	;  headerLines (I,REQ) - An array of lines containing the header for this member.
	; RETURNS:        The header string to plug into the XML description for the member.
	;---------
	formatHeaderAsDescription(headerLines) {
		; Put the lines back together
		headerText := headerLines.join("`n")
		
		; Replace double-quotes with their XML-safe equivalent
		headerText := headerText.replace("""", "&quot;")
		
		; Add a newline at the start to separate the header from the definition line in the popup
		headerText := "`n" headerText
		
		; Indent the whole thing with tabs (which appear in the XML but are ignored in the popup)
		headerText := headerText.replace("`n", "`n" this.Indent_Header)
		
		return headerText
	}
	
	;---------
	; DESCRIPTION:    Determine the full name of this member.
	; PARAMETERS:
	;  className (I,REQ) - The name of the class this member is part of.
	; RETURNS:        Either className.memberName, or just className for constructors.
	;---------
	generateFullName(className) {
		; Special case: constructors are just <className>
		if(this.name = "__New")
			return className
		
		; Full name is <class>.<member>
		return className "." this.name
	}
	
	;---------
	; DESCRIPTION:    Generate the XML for this member's parameters (if any).
	; RETURNS:        The generated XML
	;---------
	generateParamsXML() {
		if(DataLib.isNullOrEmpty(this.paramsAry))
			return ""
		
		paramsXML := ""
		For _,paramName in this.paramsAry {
			paramName := paramName.replace("""", "&quot;") ; Replace double-quotes with their XML-safe equivalent.
			xml := this.BaseXML_Param.replaceTag("PARAM_NAME", paramName)
			
			paramsXML .= "`n" xml ; Start with an extra newline to put the params block on a new line
		}
		
		return paramsXML
	}
	
	
	; #DEBUG#
	
	getDebugTypeName() {
		return "AutoCompleteMember"
	}
	; #END#
}
