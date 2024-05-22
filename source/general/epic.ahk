; Work-specific hotkeys

; Universal open of EMC2 objects from title.
; Note that some programs override this if they have special ways of providing the record string or INI/ID/title.
$!e::getEMC2ObjectFromCurrentTitle().openEdit()
$!w::getEMC2ObjectFromCurrentTitle().openWeb()
	getEMC2ObjectFromCurrentTitle() {
		; We have to check this directly instead of putting it under an #If directive, so that the various program-specific #If directives win.
		if (!Config.contextIsWork) {
			HotkeyLib.waitForRelease()
			Send, % A_ThisHotkey.removeFromStart("$")
			return ""
		}
		
		record := EpicLib.selectEMC2RecordFromText(WinGetTitle("A"))
		if (!record)
			return ""
		
		return new ActionObjectEMC2(record.id, record.ini)
	}

#If Config.contextIsWork ; Any work machine
	;region TLG record IDs
	^!+d::
		sendTLGRecId() {
			idList := ""
			For _, recId in selectTLGRecIDs("Select EMC2 Record to Send")
				idList := idList.appendPiece(", ", recId.removeFromStart("P.").removeFromStart("Q."))
			Send, % idList
		}
	^!#d::
		webTLGRecs() {
			For _, ao in selectTLGActionObjects("Select EMC2 Record to View")
				ao.openWeb()
		}
	^!+#d::
		editTLGRecs() {
			For _, ao in selectTLGActionObjects("Select EMC2 Record to Edit")
				ao.openEdit()
		}
	
	selectTLGRecIDs(title) {
		emc2Path := Config.getProgramPath("EMC2")
		icon := FileLib.getParentFolder(emc2Path, 2) "\en-US\Images\emc2.ico" ; Icon is separate from the executable so we have to jump to it.

		s := new Selector("tlg.tls").setTitle(title).setIcon(icon).overrideFieldsOff()
		s.dataTableList.filterOutIfColumnBlank("RECORD")
		s.dataTableList.filterOutIfColumnMatch("RECORD", "GET") ; Special keyword used for searching existing windows, can search for that with ^!i instead.
		return s.promptMulti("RECORD")
	}
	selectTLGActionObjects(title) {
		actionObjects := []
		For _, recId in selectTLGRecIDs(title) {
			if (recId.startsWith("P."))
				actionObjects.push(new ActionObjectEMC2(recId.removeFromStart("P."), "PRJ"))
			else if (recId.startsWith("Q."))
				actionObjects.push(new ActionObjectEMC2(recId.removeFromStart("Q."), "QAN"))
			else if (recId.startsWith("S."))
				actionObjects.push(new ActionObjectEMC2(recId.removeFromStart("S."), "SLG"))
			else
				actionObjects.push(new ActionObjectEMC2(recId, "DLG"))
		}
		
		return actionObjects
	}
	;endregion TLG record IDs

	!+e::
		selectEpicSourceFolder() {
			; Gather DLGs we already have nicer names for
			tl := new TableList("tlg.tls")
			tl.filterOutIfColumnBlank("RECORD")
			tl.filterOutIfColumnNoMatchRegEx("RECORD", "^\d+$") ; Numbers only (so current-version DLGs)
			knownDLGs := {} ; {dlgId: name}
			For recId, data in tl.getRowsByColumn("RECORD", "NAME")
				knownDLGs[recId] := { name:data["NAME_OUTPUT_PREFIX"] data["NAME"], abbrev:data["ABBREV"] }
			; Debug.popup("knownDLGs",knownDLGs)
			
			; Find all branch folders in the versioned EpicSource folders.
			folders := {} ; type => [ {name, path, abbrev} ]
			Loop, Files, C:\EpicSource\*, D
			{
				; Only consider #[#].# folders
				if (!A_LoopFileName.matchesRegEx("\d{1,2}\.\d"))
					Continue
				
				versionFolderPath := A_LoopFileLongPath
				Loop, Files, %versionFolderPath%\*, D
				{
					name := A_LoopFileName
					; Ignore binary folders
					if (name.startsWith("App "))
						Continue

					; Categorize folders + massage names for display
					if (name.startsWith("DLG-I")) {
						cat    := "SUs"
						; name   := name.replaceOne("DLG-", "DLG ")
					; } else if (name.contains("-Merge-To-")) {
					; 	cat    := "Merge"
						; name   := name.beforeString("-Merge-To-") " (Merge)"
						; name   := name.replaceOne("DLG-", "DLG ").beforeString("-Merge-To-") " (Merge)"
					} else if (name.startsWith("DLG-")) {
						cat    := "Current DLGs"
						; name   := name.replaceOne("DLG-", "DLG ")
					} else if (name = "st1" || name = "final") {
						cat    := "Integration"
					; 	name   := "Stage 1"
					; 	abbrev := "s1"
					; } else if (name = "final") {
					; 	cat    := "Integration"
					; 	name   := "Final"
					; 	abbrev := "f"
					} else {
						cat    := "User Branches"
					}


					if (name = "st1") {
						name   := "Stage 1"
						abbrev := "s1"
					} else if (name = "final") {
						name   := "Final"
						abbrev := "f"
					}

					; Merge DLGs
					if (name.contains("-Merge-To-"))
						name := name.beforeString("-Merge-To-") " (Merge)"
					; All DLGs
					if (name.contains("DLG-")) {
						dlgId := name.firstBetweenStrings("DLG-", "-")
						
						name := "DLG " dlgId
						if (knownDLGs[dlgId]) {
							name   .= " - " knownDLGs[dlgId].name
							abbrev := knownDLGs[dlgId].abbrev
						} else {
							; name   := name.replaceOne("DLG-", "DLG ")
							abbrev := ""
						}
					}

					if(!folders[cat])
						folders[cat] := []
					folders[cat].push({ name:name, path:A_LoopFileLongPath, abbrev:abbrev })
				}
			}
			; Debug.popup("folders",folders)

			s := new Selector().setTitle("Select branch folder to open:")
			; gdbtodo could we move this into Selector itself? As in, it forces abbreviations to be unique when you add a choice (either specifically as part of .addChoice() or as part of loading the choices)?
			; gdbtodo that would let us do away with the abbrevPrefix here - just set it as the abbreviation above and let Selector handle it for us.
			; gdbtodo even if not, could do the same thing here - rather than passing a prefix, just set it above and have addFolderChoicesForType use the given as a default (but force it to be unique).
			allAbbrevs := []

			addFolderChoicesForType(s, folders, "Current DLGs",     "d", allAbbrevs)
			; addFolderChoicesForType(s, folders, "Merge",       "m", allAbbrevs)
			addFolderChoicesForType(s, folders, "User Branches",        "u", allAbbrevs)
			addFolderChoicesForType(s, folders, "SUs",         "s", allAbbrevs)
			addFolderChoicesForType(s, folders, "Integration", "i", allAbbrevs)

			path := s.prompt("PATH")
			; Debug.popup("path",path)
			if(path)
				Run(path)
		}
		addFolderChoicesForType(s, folders, type, abbrevPrefix, allAbbrevs) {
			if (folders[type].length() <= 0)
				return

			s.addSectionHeader(type)
			For _, f in folders[type] {
				abbrev := f.abbrev ? f.abbrev : DataLib.forceUniqueValue(abbrevPrefix, allAbbrevs)
				s.addChoice(new SelectorChoice({ NAME:f.name, ABBREV:abbrev, PATH: f.path }))
			}
		}
	
	^+!#h::
		selectHyperspace() {
			environments := EpicLib.selectEpicEnvironments("Launch Classic Hyperspace in Environment")
			For _, env in environments
				EpicLib.runHyperspace(env["VERSION"], env["COMM_ID"], env["TIME_ZONE"])
		}
		
	^!#h::
		selectHSWeb() {
			environments := EpicLib.selectEpicEnvironments("Launch Standalone HSWeb in Environment", Config.getProgramPath("Chrome"))
			For _, env in environments
				Run(env["HSWEB_URL"])
		}
	
	^!+h::
		selectHyperdrive() {
			environments := EpicLib.selectEpicEnvironments("Launch Hyperdrive in Environment", Config.getProgramPath("Hyperdrive"))
			For _, env in environments
				EpicLib.runHyperdrive(env["COMM_ID"], env["TIME_ZONE"])
		}
	
	^!+i::
		selectEnvironmentId() {
			environments := EpicLib.selectEpicEnvironments("Insert ID for Environment")
			For _, env in environments {
				Send, % env["ENV_ID"]
				Send, {Enter} ; Submit it too.
			}
		}
	
	^!#s::
		selectSnapper() {
			selectedText := SelectLib.getText()
			record := new EpicRecord().initFromRecordString(selectedText)
			
			; Don't include invalid INIs (anything that's not 3 characters)
			if (record.ini && record.ini.length() != 3)
				record := ""
			
			s := new Selector("epicEnvironments.tls").setTitle("Open Record(s) in Snapper in Environment").setIcon(Config.getProgramPath("Snapper"))
			s.addOverrideFields(["INI", "ID"]).setDefaultOverrides({"INI":record.ini, "ID":record.id}) ; Add fields for INI/ID and default in any values that we figured out
			environments := s.promptMulti() ; Each individual element is for a specific environment, which also includes any specified records.
			For _, env in environments {
				if (env["COMM_ID"] = "LAUNCH") ; Special keyword - just launch Snapper, not any specific environment.
					Config.runProgram("Snapper")
				else
					Snapper.addRecords(env["COMM_ID"], env["INI"], env["ID"]) ; env["ID"] can contain a list or range if that's what the user entered
			}
		}
	
	; Turn clipboard into standard EMC2 string and send it.
	!+n:: sendStandardEMC2ObjectString()
	!+#n::sendStandardEMC2ObjectString(true) ; ID only
	sendStandardEMC2ObjectString(idOnly := false) {
		HotkeyLib.waitForRelease()
		
		record := EpicLib.selectEMC2RecordFromText(clipboard)
		if (!record)
			return
		ini := record.ini
		id  := record.id
		
		if (idOnly)
			Send, % id
		else if (Config.isWindowActive("Chrome Workplans"))
			ClipboardLib.send(EpicLib.buildEMC2ObjectString(record, true)) ; Put title first for workplans
		else
			ClipboardLib.send(EpicLib.buildEMC2ObjectString(record)) ; Must send with clipboard because it can contain hotkey chars
		
		; Special case for OneNote: link the INI/ID as well.
		if (Config.isWindowActive("OneNote"))
			OneNote.linkEMC2ObjectInLine(ini, id)
	}

	; Pull EMC2 record IDs from currently open window titles and prompt the user to send one.
	^!i::
		sendEMC2RecordID() {
			record := EpicLib.selectEMC2RecordFromUsefulTitles()
			if (record)
				SendRaw, % record.id
		}

#If Config.machineIsWorkDesktop ; Main work desktop only
	^!+r::
		selectThunder() {
			environments := EpicLib.selectEpicEnvironments("Launch Thunder for Environment", Config.getProgramPath("Thunder"))
			For _, env in environments {
				if (env["COMM_ID"] = "LAUNCH") ; Special keyword - just show Thunder itself, don't launch an environment.
					Config.activateProgram("Thunder")
				else
					EpicLib.runThunderForEnvironment(env["ENV_ID"])
			}
		}
	
	^!+v::
		selectVDI() {
			environments := EpicLib.selectEpicEnvironments("Launch VDI for Environment", Config.getProgramPath("VMware Horizon Client"))
			For _, env in environments {
				if (env["COMM_ID"] = "LAUNCH") { ; Special keyword - just show VMWare itself, don't launch a specific VDI.
					Config.runProgram("VMware Horizon Client")
				} else {
					EpicLib.runVDI(env["VDI_ID"])
					
					; Also fake-maximize the window once it shows up.
					if (environments.length() = 1) { ; But don't bother if we're dealing with multiple windows - just launch them all at once and I'll fix the size manually.
						WinWaitActive, ahk_exe vmware-view.exe, , 10, VMware Horizon Client ; Ignore the loading-type popup that happens initially with excluded title.
						if (!ErrorLevel) ; Set if we timed out or if somethign else went wrong.
							WindowPositions.fixWindow()
					}
				}
			}
		}
#If
