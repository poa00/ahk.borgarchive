; Hotkeys to run/activate various programs.

#s::  MainConfig.runProgram("Spotify") ; Can't unminimize from tray with any reasonable logic, so re-run to do so.
#f::  MainConfig.activateProgram("Everything")
#t::  MainConfig.runProgram("Telegram")
!+g:: MainConfig.activateProgram("GitHub")
!`::  MainConfig.activateProgram("Process Explorer")
^+!g::MainConfig.activateProgram("Chrome")
^+!n::MainConfig.activateProgram("Notepad++")
^+!o::MainConfig.activateProgram("OneNote")
^+!x::MainConfig.activateProgram("Launchy")
^+!y::MainConfig.activateProgram("yEd")
^!#f::MainConfig.runProgram("Firefox Portable")
^!#n::MainConfig.runProgram("Notepad")
^!#z::MainConfig.activateProgram("FileZilla")
^!#/::MainConfig.activateProgram("AutoHotkey WinSpy")

#If MainConfig.isMachine(MACHINE_EpicLaptop)
	^+!e::MainConfig.activateProgram("EMC2")
	^+!s::MainConfig.activateProgram("EpicStudio")
	^+!u::MainConfig.activateProgram("Thunder")
	^+!v::MainConfig.runProgram("VB6")
	^!#e::MainConfig.activateProgram("Outlook")
	^!#v::MainConfig.activateProgram("Visual Studio")
#If
