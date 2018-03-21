; note to self: this must be in UTF-8 encoding.

#Hotstring * ; Default option: hotstrings do not require an ending character. Use *0 to turn it off for hotstrings that as needed.

#If !MainConfig.windowIsGame()
{ ; Emails.
	:X:emaila::Send,  % USER_EMAIL
	:X:gemaila::Send, % USER_EMAIL_2
	:X:eemaila::Send, % EPIC_EMAIL
	:X:oemaila::Send, % USER_OUTLOOK_EMAIL
}

{ ; Addresses.
	:X:waddr::
		SendRaw, % madisonAddress
	return
	
	:X:eaddr::
		Send, % epicAddress
	return
	:*0X:ezip::
		Send, % epicAddressZip
	return
}

{ ; Logins.
	:X:uname::Send, % USER_USERNAME
}

{ ; Phone numbers.
	:X:phoneno::Send, % USER_PHONE_NUM
	:X:fphoneno::Send, % reformatPhone(USER_PHONE_NUM)
}

{ ; Typo correction.
	:*0:,3::<3
	::<#::<3
	::<43::<3
	:::0:::)
	::;)_::;)
	:::)_:::)
	:::)(:::)
	::O<o::O,o
	::o<O::o,O
	::O<O::O,O
	:R:^<^::^,^
	:R:6,6::^,^
	:R:6,^::^,^
	:R:^,6::^,^
	::*shurgs*::*shrugs*
	::mmgm::mmhm
	::fwere::fewer
	::aew::awe
	::teh::the
	::tteh::teh
	::nayone::anyone
	::idneed::indeed
	::seriuosly::seriously
	::.ocm::.com
	::heirarchy::hierarchy
	:*0:previou::previous
	::previosu::previous
	::dcb::dbc
	::h?::oh?
}

{ ; Expansions.
	{ ; General
		::gov't::government
		::eq'm::equilibrium
		::f'n::function
		::tech'l::technological
		::eq'n::equation
		::pop'n::population
		::def'n::definition
		::int'l::international
		::int'e::internationalize
		::int'd::internationalized
		::int'n::internationalization
		::ppt'::powerpoint
		::conv'l::conventional
		::Au'::Australia
		::char'c::characteristic
		::intro'd::introduced
		::dev't::development
		::civ'd::civilized
		::ep'n::European
		::uni'::university
		::sol'n::solution
		::sync'd::synchronized
		::pos'n::position
		::pos'd::positioned
		::imp't::implement
		::imp'n::implementation
		::add'l::additional
		::org'n::organization
		::doc'n::documentation
		::hier'l::hierarchical
		::heir'l::hierarchical
		::qai::QA Instructions
		::acc'n::association
		::inf'n::information
		::info'n::information
		
		::.iai::...I'll allow it
		::iai::I'll allow it
		::asig::and so it goes, and so it goes, and you're the only one who knows...
	}

	{ ; Billing
		::col'n::collection
		::coll'n::collection
		::auth'n::authorization
	}
}
	
{ ; Date and time.
	:*0:idate::
		sendDateTime("M/d/yy")
		
		; Excel special.
		if(WinActive("ahk_class XLMAIN"))
			Send, {Tab}
	return
	
	:X:dashidate::sendDateTime("M-d-yy")
	:X:uidate::sendDateTime("M_d_yy")
	:X:didate::sendDateTime("dddd`, M/d")
	:X:iddate::sendDateTime("M/d`, dddd")
	
	:X:itime::sendDateTime("h:mm tt")
	
	::idatetime::
	::itimedate::
		sendDateTime("h:mm tt M/d/yy")
	return
	
	; Arbitrary dates/times, translates
	:X:aidate::queryDateAndSend()
	:X:aiddate::queryDateAndSend("M/d/yy`, dddd")
	:X:adidate::queryDateAndSend("dddd`, M/d/yy")
	queryDateAndSend(format = "M/d/yy") {
		date := queryDate(format)
		if(date)
			SendRaw, % date
	}
	
	::aitime::
		queryTimeAndSend() {
			time := queryTime()
			if(time)
				SendRaw, % time
		}
}

{ ; URLs.
	::lpv::chrome-extension://hdokiejnpimakedhajhdlcegeplioahd/vault.html
}

{ ; Folders and paths.
	{ ; General
		::pff::C:\Program Files\
		::xpff::C:\Program Files (x86)\
		
		:X:urf::sendFolderPath("USER_ROOT")
		:X:deskf::sendFolderPath("USER_ROOT", "Desktop")
		:X:dsf::sendFolderPath("USER_ROOT", "Design")
		:X:dlf::sendFolderPath("DOWNLOADS")
		:X:devf::sendFolderPath("USER_ROOT", "Dev")
	}

	{ ; AHK
		:X:arf::sendFolderPath("AHK_ROOT")
		:X:aconf::sendFolderPath("AHK_CONFIG")
		:X:alconf::sendFolderPath("AHK_LOCAL_CONFIG")
		:X:atf::sendFolderPath("AHK_ROOT", "test")
		:X:asf::sendFolderPath("AHK_SOURCE")
		:X:acf::sendFolderPath("AHK_SOURCE", "common")
		:X:apf::sendFolderPath("AHK_SOURCE", "program")
		:X:agf::sendFolderPath("AHK_SOURCE", "general")
		:X:astf::sendFolderPath("AHK_SOURCE", "standalone")
	}

	{ ; Epic - General
		:X:epf::sendFolderPath("EPIC_PERSONAL")
		:X:ssf::sendFolderPath("USER_ROOT", "Screenshots")
		:X:enfsf::sendFolderPath("EPIC_NFS_3DAY")
		:X:eunfsf::sendUnixFolderPath("EPIC_NFS_3DAY_UNIX")
		
		:X:ecompf::sendFolderPath("VB6_COMPILE")
	}
	
	{ ; Epic - Source
		:X:esf::sendFolderPath("EPIC_SOURCE_S1")
		:X:fesf::sendFilePath("EPIC_SOURCE_S1", epicDesktopProject)
	}
}

{ ; AHK.
	::dbpop::
		SendRaw, DEBUG.popup(") ; ending quote for syntax highlighting: "
		Send, {Left} ; Get inside parens
	return
}
#IfWinNotActive
#Hotstring

; Edits this file.
^!h::
	editScript(A_LineFile)
return
