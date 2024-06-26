/* Class which represents a particular change (mod action) that should be made to a "row" array in a TableList.
	
	A mod action is defined by a string using a particular syntax:
		~COLUMN.OPERATION(TEXT)
			COLUMN    - The name of the column that this mod action should apply to.
			OPERATION - A string (that matches one of the TableListMod.Operation_* constants below) what we want to do (see "Operations" section).
			TEXT      - The text that is used by the operation (see "Operations" section).
		Example:
			~PATH.addToStart(C:\users\)
		Result:
			All rows which the mod is applied to will have the string "C:\users\" added to the beginning of their "PATH" column.
	
	;region Operations
	The operation of a mod action determines how it changes the chosen column:
		replaceWith
			Replace the column.
			Example:
				Mod string
					~COL.replaceWith(z)
				Normal line (COL column)
					AAA
				Result
					z
		
		addToStart
			Prepend to the column (add to the beginning).
			Example:
				Mod string
					~COL.addToStart(z)
				Normal line (COL column)
					AAA
				Result
					zAAA
		
		addToEnd
			Append to the column (add to the end).
			Example:
				Mod string
					~COL.addToEnd(z)
				Normal line (COL column)
					AAA
				Result
					AAAz
	;endregion Operations
*/

class TableListMod {
	;region ------------------------------ PUBLIC ------------------------------
	;---------
	; DESCRIPTION:    The prefix character for mods, that comes just before the column to affect.
	;---------
	static Char_TargetPrefix := "~"
	
	;---------
	; DESCRIPTION:    Create a new TableListMod instance.
	; PARAMETERS:
	;  modActString (I,REQ) - String defining the mod. Format (explained in class documentation):
	;                         	~COLUMN.OPERATION(TEXT)
	; RETURNS:        Reference to new TableListMod object
	;---------
	__New(modString) {
		; Pull the relevant info out of the string.
		this.column    := modString.firstBetweenStrings(this.Char_TargetPrefix, ".")
		this.operation := modString.firstBetweenStrings(".", "(")
		this.text      := modString.allBetweenStrings("(", ")") ; Go to the last close-paren, to allow other close-parens in the string
		
		; Debug.popup("New TableListMod","Finished", "State",this)
	}
	
	;---------
	; DESCRIPTION:    Perform the action described in this mod on the given row.
	; PARAMETERS:
	;  row (IO,REQ) - Associative array of column names => column values for a single row.
	;                 Will be updated according to the action described in this mod.
	;---------
	executeMod(ByRef row) {
		columnValue := row[this.column]
		
		if(DataLib.isArray(columnValue)) {
			newValue := []
			For _,value in columnValue {
				newValue.Push(this.executeOnce(value))
			}
		} else {
			newValue := this.executeOnce(columnValue)
		}
		
		; Debug.popup("Row",row, "Column to modify",this.column, "Column value to modify",columnValue, "Operation",this.operation, "Text",this.text, "Result",newValue, "Mod",this)
		
		; Put the column back into the full row.
		row[this.column] := newValue
	}
	;endregion ------------------------------ PUBLIC ------------------------------

	;region ------------------------------ PRIVATE ------------------------------
	column    := "" ; The name of the column to operate on
	operation := "" ; The operation to perform
	text      := "" ; The text to use
	
	;---------
	; DESCRIPTION:    Execute the mod on a single value.
	; PARAMETERS:
	;  value (I,REQ) - The value to use.
	; RETURNS:        The updated result.
	;---------
	executeOnce(value) {
		; These map to the modOperation section in my TableList language definition.
		Switch this.operation {
			Case "addToStart":  return this.text value
			Case "addToEnd":    return value this.text
			Case "replaceWith": return this.text
			Case "defaultTo":   return (value != "") ? value : this.text
		}
	}
	;endregion ------------------------------ PRIVATE ------------------------------
}
