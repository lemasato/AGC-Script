EnvGet, userprofile, userprofile
global userprofile
global programName := "Game Vivifier"
global iniFilePath := userprofile "\Documents\AutoHotKey\" programName "\Preferences.ini"

Process, Close, Game Vivifier.exe 
Process, WaitClose, Game Vivifier.exe
Sleep 1000
FileMove,% A_ScriptDir "\Game Vivifier NewVersion.exe", % A_ScriptDir "\Game Vivifier.exe", 1
if ( ErrorLevel ) {
	FileDelete, % A_ScriptDir "\Game Vivifier NewVersion.exe"
	MsgBox,0x40010,, An error occured while updating!`nAuto-update was turned off for safety!
}
else Run, % A_ScriptDir "\Game Vivifier.exe"
ExitApp

