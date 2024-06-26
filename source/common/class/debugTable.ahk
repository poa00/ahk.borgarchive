﻿/* A debug class which generates a structured table of recursive information about the given values.
		Note that this really only works with monospace fonts.
	
	Motivation
		This class is intended to show information in a more structured and considerably deeper way than simply showing the value of a variable. It:
			* Recurses into objects
			* Supports label-object pairs in a single function call (variadic arguments instead of building an array yourself)
			* Supports more specific information from objects/classes which implement a couple of extra properties (see "Special Properties and Functions" below)
	
	Evaluating value parameters
		Values: Simple values like strings and numbers will be displayed normally.
		Arrays: Numeric arrays will start with a line reading "Array (numIndices)", where numIndices is the count of indices in the array. Then, each of the indices in the array will be shown in square brackets next to their corresponding values. For example:
				Array (2)
					[1] A
					[2] B
			Associative arrays work the same way, with the actual indices inside the square brackets.
		Objects: If an object has implemented the .Debug_ToString() function, it will be displayed as described in the "Special Properties and Functions" section below. If not, it will be treated the same as an array or object (where we show the subscripts [variables] underneath an "Array [numVariables]" or "Object {numVariables}" line.
	
	Special Properties and Functions
		If a class has the following properties and functions, Debug.popup/.toast will display information about an instance of that class differently.
			
;		.Debug_ToString(ByRef table)
			If this is implemented, we will use the text generated by this function instead of recursing into the object itself.
			The table argument that will be passed is an instance of the DebugTable class, which will take function calls to fill it out. See the DebugTable class for more details.
	
	Example Usage
;		; Data
;		value := 1
;		numericArray := ["value1", "value2"]
;		assocArray := {"label1":"value1", "label2":"value2"}
;		
;		class ObjectWithDebug {
;			__New() {
;				this.var1 := "A"
;				this.var2 := "B"
;			}
;			
;			Debug_ToString(ByRef table) {
;				table.addLine("Descriptive name of property 1", this.var1)
;				table.addLine("Descriptive name of property 2", this.var2)
;			}
;		}
;		objectInstance := new ObjectWithDebug()
;		
;		; Basic table with no border
;		table1 := new DebugTable().setBorderType(TextTable.BorderType_None)
;		table1.addPairs("A",value, "B",numericArray, "C",assocArray, "D",objectInstance)
;		table1.getText()
;			A:  1                                     
;			B:  ┌ Array (2) ─┐                        
;			    │ 1:  value1 │                        
;			    │ 2:  value2 │                        
;			    └────────────┘                        
;			C:  ┌── Object (2) ───┐                   
;			    │ label1:  value1 │                   
;			    │ label2:  value2 │                   
;			    └─────────────────┘                   
;			D:  ┌───────── ObjectWithDebug ──────────┐
;			    │ Descriptive name of property 1:  A │
;			    │ Descriptive name of property 2:  B │
;			    └────────────────────────────────────┘
;		
;		; Title at top + thick border (if >=50 lines long, title also added to bottom)
;		table2 := new DebugTable("Debug Info").setBorderType(TextTable.BorderType_BoldLine)
;		table2.addPairs("A",value, "B",numericArray, "C",assocArray, "D",objectInstance)
;		table2.getText()
;			┏━━━━━━━━━━━━━━━━ Debug Info ━━━━━━━━━━━━━━━━┓
;			┃ A:  1                                      ┃
;			┃ B:  ┌ Array (2) ─┐                         ┃
;			┃     │ 1:  value1 │                         ┃
;			┃     │ 2:  value2 │                         ┃
;			┃     └────────────┘                         ┃
;			┃ C:  ┌── Object (2) ───┐                    ┃
;			┃     │ label1:  value1 │                    ┃
;			┃     │ label2:  value2 │                    ┃
;			┃     └─────────────────┘                    ┃
;			┃ D:  ┌───────── ObjectWithDebug ──────────┐ ┃
;			┃     │ Descriptive name of property 1:  A │ ┃
;			┃     │ Descriptive name of property 2:  B │ ┃
;			┃     └────────────────────────────────────┘ ┃
;			┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
*/

class DebugTable extends TextTable {
	;region ------------------------------ PUBLIC ------------------------------
	;---------
	; DESCRIPTION:    How many characters wide a tab should be considered.
	;---------
	static TabWidth := 4
	
	;---------
	; DESCRIPTION:    Create a new DebugTable instance.
	; PARAMETERS:
	;  title (I,OPT) - If you want to show a title at the top of the table, pass it in here. If
	;                  given and the table gets >=50 lines tall, this title will also appear at
	;                  the bottom.
	;---------
	__New(title := "") {
		this.setTitle(title)
		this.setBorderType(TextTable.BorderType_Line)
	}
	
	;---------
	; DESCRIPTION:    Add a set of paired parameters to the table.
	; PARAMETERS:
	;  params* (I,REQ) - As many parameters as needed, in label,value pairs
	;                    (i.e. "label1",value1,"label2",value2...)
	;---------
	addPairs(params*) {
		; Special case: if the first parameter starts with a + character, treat it as a subtitle.
		if(params[1].startsWith("+")) {
			subtitle := params.removeAt(1).removeFromStart("+")
			this.setTitle(this.title.appendPiece(": ", subtitle))
		}
		
		Loop, % params.MaxIndex() // 2 {
			label := params[A_Index * 2 - 1]
			value := params[A_Index * 2]
			this.addLine(label, value)
		}
	}
	
	;---------
	; DESCRIPTION:    Add a single label/value pair to the table.
	; PARAMETERS:
	;  label (I,REQ) - The label to show next to the value.
	;  value (I,REQ) - The value to show information about.
	;---------
	addLine(label, value) {
		this.addRow(label ":", this.buildValueDebugString(value))
	}
	
	;---------
	; DESCRIPTION:    Get the text for the table.
	; RETURNS:        The generated text.
	;---------
	getText() {
		; Also add the title to the bottom if the table ends up tall enough.
		if(this.getHeight() > 50)
			this.setBottomTitle(this.title)
		
		return base.getText()
	}
	;endregion ------------------------------ PUBLIC ------------------------------
	
	;region ------------------------------ PRIVATE ------------------------------
	title := "" ; The title to show at the top (and bottom, if we get tall enough)
	
	;---------
	; DESCRIPTION:    Set the title for this table. Will be used for the top title, and if the table is tall enough, the
	;                 bottom title as well. This mostly exists to ensure that we update our base's top title whenever we
	;                 update the title.
	; PARAMETERS:
	;  title (I,REQ) - The new title.
	;---------
	setTitle(title) {
		this.title := title
		this.setTopTitle(title) ; Must be set as early as possible so table width is correct if the title is the longest thing.
	}
	
	;---------
	; DESCRIPTION:    Build a formatted string for the given value (a smaller DebugTable instance for arrays/objects).
	; PARAMETERS:
	;  value (I,REQ) - The value to generate an explanation of.
	; RETURNS:        The generated text
	;---------
	buildValueDebugString(value) {
		; Base case - not a complex object, just return the value to show.
		if(!isObject(value))
			return this.convertWhitespace(value)
		
		; Just display the name if it's an empty object (like an empty array)
		objName := this.getObjectName(value)
		if(value.count() = 0)
			return objName
		
		; Compile child values
		childTable := new DebugTable(objName)
		if(isFunc(value.Debug_ToString)) { ; If an object has its own debug logic, use that rather than looping.
			value.Debug_ToString(childTable)
		} else {
			For subLabel,subVal in value
				childTable.addLine(subLabel, subVal)
		}
		
		return childTable.getText()
	}
	
	;---------
	; DESCRIPTION:    Convert certain whitespace strings into visible characters so we can see differences in width, etc.
	;                 more easily.
	; PARAMETERS:
	;  value (I,REQ) - The string to convert
	; RETURNS:        The converted string
	;---------
	convertWhitespace(value) {
		; Replace tabs with an arrow made up of width-1 characters (same width as tabs in Notepad++), so it's
		; the desired width but more visible and doesn't mess with the layout.
		line := "―" ; U+0x2015
		head := "→" ; U+0x2192
		arrow := StringLib.duplicate(line, this.TabWidth - 1) head
		value := value.replace(A_Tab, arrow)
		
		; Replace leading, trailing, and more than 1 space in a row with dots so they're more visible.
		dot := "·" ; U+0x00B7
		while(value.matchesRegEx("  +", match)) {  ; 2+ spaces in a row
			replaceWith := StringLib.duplicate(dot, match.length()) ; Replace them with the same number of dots
			value := value.replace(match, replaceWith)
		}
		if(value.startsWith(A_Space)) ; These come after in case there are 2 leading/trailing spaces (which this would make only 1, failing the above pattern).
			value := dot value.removeFromStart(A_Space)
		if(value.endsWith(A_Space))
			value := value.removeFromEnd(A_Space) dot
		
		return value
	}
	
	;---------
	; DESCRIPTION:    Get the name describing the given object, based on its class name.
	; PARAMETERS:
	;  value (I,REQ) - The value to name
	; RETURNS:        The chosen name
	;---------
	getObjectName(value) {
		; For simple arrays and objects, use a generic label and add the number of elements.
		if(DataLib.isArray(value))
			return "Array [" value.count() "]"
		if(DataLib.isObject(value))
			return "Object {" value.count() "}"
		
		; Otherwise just use the class name.
		return value.__Class
	}
	;endregion ------------------------------ PRIVATE ------------------------------
}
