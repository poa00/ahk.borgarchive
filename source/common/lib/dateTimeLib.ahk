; Date and time utility functions.

class DateTimeLib {
	;region ------------------------------ PUBLIC ------------------------------
	;---------
	; DESCRIPTION:    Replace tags matching different formats supported by FormatTime.
	; PARAMETERS:
	;  inString (I,REQ) - The string to replace tags in
	;  dateTime (I,OPT) - The date/time to use when replacing tags
	; RETURNS:        The updated string
	;---------
	replaceTags(inString, instant := "") { ; instant defaults to A_Now (based on FormatTime's behavior)
		outString := inString
		
		; All formats supported by FormatTime
		formatsAry := ["d","dd","ddd","dddd","M","MM","MMM","MMMM","y","yy","yyyy","gg","h","hh","H","HH","m","mm","s","ss","t","tt","","Time","ShortDate","LongDate","YearMonth","YDay","YDay0","WDay","YWeek"]
		
		For _,format in formatsAry {
			dateTimeBit := FormatTime(instant, format)
			outString := outString.replaceTag(format, dateTimeBit)
		}
		
		return outString
	}

	;---------
	; DESCRIPTION:    Figure out the last date in the provided month/year.
	; PARAMETERS:
	;  monthNum (I,OPT) - The month number to check
	;  year     (I,OPT) - The year to check
	; RETURNS:        The last date (with leading 0) in the given month.
	;---------
	getLastDateOfMonth(monthNum := "", year := "") {
		; Default in today's month/year if either is not given
		monthNum := monthNum ? monthNum : A_MM   ; Current month number (with leading 0, though that doesn't matter)
		year     := year     ? year     : A_YYYY ; Current year
		
		; Get number of the next month
		nextMonthNum := monthNum + 1
		if(nextMonthNum = 13) ; Wrap around at end of year
			nextMonthNum := 1
		
		dateString := year nextMonthNum.prePadToLength(2, "0") ; First day of following month in YYYYMM format
		dateString += -1, Days ; Go back a day to get to the last day of the given month
		
		return FormatTime(dateString, "dd") ; Date with leading 0 (matches A_DD)
	}
	;endregion ------------------------------ PUBLIC ------------------------------
}
