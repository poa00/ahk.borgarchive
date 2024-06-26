class Telegram {
	;region ------------------------------ PUBLIC ------------------------------
	;---------
	; DESCRIPTION:    Share the provided URL to Telegram and focus the normal chat.
	; PARAMETERS:
	;  url (I,REQ) - The URL to share.
	;---------
	shareURL(url) {
		launchURL := this.ShareURLBase.replaceTag("URL", url)
		Run(launchURL)
		
		WinWaitActive, % Config.windowInfo["Telegram"].idString
		Sleep, 500 ; Give the share faux-popup time to appear.
		
		Send, {Down 2}{Enter} ; Select my target chat (the "Normal" one).
	}
	;endregion ------------------------------ PUBLIC ------------------------------
	
	;region ------------------------------ INTERNAL ------------------------------
	;---------
	; DESCRIPTION:    Focus the "Normal" chat that's the only one I use in Telegram.
	;---------
	focusNormalChat() {
		Send, ^1
	}
	;endregion ------------------------------ INTERNAL ------------------------------
	
	;region ------------------------------ PRIVATE ------------------------------
	; Shares the given URL to telegram desktop, prompting you to pick a chat.
	static ShareURLBase := "tg://msg_url?url=<URL>"
	;endregion ------------------------------ PRIVATE ------------------------------
}
