#Include %A_LineFile%\..\actionObjectBase.ahk
#Include %A_LineFile%\..\actionObjectCodeSearch.ahk
#Include %A_LineFile%\..\actionObjectEMC2.ahk
#Include %A_LineFile%\..\actionObjectEpicStudio.ahk
#Include %A_LineFile%\..\actionObjectHelpdesk.ahk
#Include %A_LineFile%\..\actionObjectPath.ahk

/* Class that figures out what kind of ActionObject* class is needed based on the input (and prompting the user) and returns it.
	
	Example Usage
		; Determine type based on input
		ao := new ActionObjectRedirector("DLG 123456") ; This will be an EMC2-type object, so ao is an ActionObjectEMC2 instance
		ao.openWeb() ; Open the web version of the object
		
		; Will prompt user for both type and value with Selector popup because neither given
		ao := new ActionObjectRedirector()
		ao.linkSelectedTextWeb() ; Links the selected text with a link built from the specific ActionObject* class in question
*/

class ActionObjectRedirector {

; ====================================================================================================
; ============================================== PUBLIC ==============================================
; ====================================================================================================
	
	;---------
	; DESCRIPTION:    Determine the type of ActionObject class to use based on the type/value
	;                 and return a new instance of that class.
	; PARAMETERS:
	;  value (I,OPT) - Input value to evaluate.
	; RETURNS:        An instance of ActionObject* (Code, EMC2, etc.) for the chosen type.
	; NOTES:          This does NOT return an ActionObjectRedirector instance.
	;---------
	__New(value := "") {
		this.value := value
		this.value := this.value.firstLine().clean() ; Only first line, remove leading/trailing spaces and odd characters from value
		
		this.determineType()
		this.selectMissingInfo()
		
		; DEBUG.toast("ActionObjectRedirector","All info determined", "this",this)
		return this.getTypeSpecificObject()
	}
	
	
; ====================================================================================================
; ============================================== PRIVATE =============================================
; ====================================================================================================
	
	value   := "" ; Value (the unique bit of info to act upon, like a path or identifier)
	type    := "" ; Determined type of ActionObject, from .Type_* constants
	subType := "" ; Determined sub-type, an additional categorization within a particular ActionObject* class.
	
	; Type constants
	static Type_CodeSearch := "CODESEARCH"
	static Type_EpicStudio := "EPICSTUDIO"
	static Type_EMC2       := "EMC2"
	static Type_Helpdesk   := "HELPDESK"
	static Type_Path       := "PATH"
	
	;---------
	; DESCRIPTION:    Try to determine the type of ActionObject that we'll need based on the input value.
	; SIDE EFFECTS:   tryProcessAs* functions may set .value, .type, and .subType.
	;---------
	determineType() {
		; Try parsing as an Epic Record for use in EMC2/HDR checks
		record := new EpicRecord(this.value)
		if(record.id != "") {
			if(this.tryProcessAsEMC2(record))
				return
			if(this.tryProcessAsHelpdesk(record))
				return
		}
		
		if(this.tryProcessAsPath())
			return
	}
	
	;---------
	; DESCRIPTION:    Try to determine whether the value is an EMC2 object.
	; PARAMETERS:
	;  record (I,REQ) - EpicRecord instance that's parsed the input into ini/id/title.
	; RETURNS:        True if the value was determined to be an EMC2 object, False otherwise.
	; SIDE EFFECTS:   Sets .type, .subType, and .value if the value is an EMC2 object.
	;---------
	tryProcessAsEMC2(record) {
		; Silent selection from actionObject TLS to see if we match an EMC2-type INI (filtered list so no match means not EMC2).
		s := new Selector("actionObject.tls")
		s.dataTL.filterByColumn("TYPE", ActionObjectRedirector.Type_EMC2)
		this.ini := s.selectChoice(this.ini, "SUBTYPE")
		
		data := s.selectChoice(record.ini)
		if(!data)
			return false
		
		; We successfully identified the type, store off the pieces we know.
		this.type    := data["TYPE"]
		this.subType := data["SUBTYPE"]
		this.value   := record.id ; From initial parsing of value above
		return true
	}
	
	;---------
	; DESCRIPTION:    Try to determine whether the value is a helpdesk object.
	; PARAMETERS:
	;  record (I,REQ) - EpicRecord instance that's parsed the input into ini/id/title.
	; RETURNS:        True if the value was determined to be a helpdesk object, False otherwise.
	; SIDE EFFECTS:   Sets .type and .value if the value is a helpdesk object.
	;---------
	tryProcessAsHelpdesk(record) {
		if(record.ini != "HDR" || !record.id.isNum())
			return false
		
		this.type  := this.Type_Helpdesk
		this.value := record.id
	}
	
	;---------
	; DESCRIPTION:    Try to determine whether the value is a path.
	; RETURNS:        True if the value was determined to be a path, False otherwise.
	; SIDE EFFECTS:   Sets .type and .subType if the value was a path.
	;---------
	tryProcessAsPath() {
		pathType := ActionObjectPath.determinePathType(this.value)
		if(pathType = "")
			return false
		
		this.type    := this.Type_Path
		this.subType := pathType
		return true
	}
	
	;---------
	; DESCRIPTION:    Prompt the user for a value and/or type if those values are missing.
	; SIDE EFFECTS:   Sets .type, .subType, and .value based on the user's input.
	;---------
	selectMissingInfo() {
		; Nothing is missing
		if(this.value != "" && this.type != "")
			return
		
		data := new Selector("actionObject.tls").selectGui("", "", {"VALUE":this.value})
		if(!data)
			return
		
		this.type    := data["TYPE"]
		this.subType := data["SUBTYPE"]
		this.value   := data["VALUE"]
	}
	
	;---------
	; DESCRIPTION:    Create a new ActionObject* instance matching the chosen type.
	; RETURNS:        New instance of an ActionObject* class
	;---------
	getTypeSpecificObject() {
		if(this.type = "")
			return "" ; No determined type, silent quit, return nothing
		
		if(this.type = this.Type_CodeSearch)
			return new ActionObjectCodeSearch(this.value)
		
		if(this.type = this.Type_EpicStudio)
			return new ActionObjectEpicStudio(this.value, this.subType)
		
		if(this.type = this.Type_EMC2)
			return new ActionObjectEMC2(this.value, this.subType)
		
		if(this.type = this.Type_Helpdesk)
			return new ActionObjectHelpdesk(this.value)
		
		if(this.type = this.Type_Path)
			return new ActionObjectPath(this.value, this.subType)
		
		new ErrorToast("Unrecognized type", "ActionObjectRedirector doesn't know what to do with this type: " this.type).showMedium()
		return ""
	}
}
