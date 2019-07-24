; Send a specific media key, to be executed by external program (like Microsoft keyboard special keys).
#NoEnv                       ; Recommended for performance and compatibility with future AutoHotkey releases.
#SingleInstance, Force       ; Running this script while it's already running just replaces the existing instance.
SendMode, Input              ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir, %A_ScriptDir% ; Ensures a consistent starting directory.

#Include <includeCommon>

inputKey = %1% ; Input from command line
if(!inputKey)
	ExitApp

inputKeyAry := StrSplit(inputKey, ",")

For i,inputKey in inputKeyAry
	sendMediaKey(inputKey)

ExitApp
