EnvGet, userprofile, userprofile
global userprofile
global programName := "Game Vivifier"
global iniFilePath := userprofile "\Documents\AutoHotKey\" programName "\Preferences.ini"
IniRead, programPID,% iniFilePath,SETTINGS,PID
IniRead, fileName,% iniFilePath,SETTINGS,FileName

if ( programPID != "ERROR" || programPID "" )
	Process, Close, %programPID%
Process, Close, Game Vivifier.exe
Process, Close, Game-Vivifier.exe
Sleep 2000
FileDelete,% A_ScriptDir "\" fileName
FileDelete,% A_ScriptDir "\Game Vivifier.exe"
FileDelete,% A_ScriptDir "\Game-Vivifier.exe"
sleep 1000
FileMove,% A_ScriptDir "\Game Vivifier NewVersion.exe", % A_ScriptDir "\Game Vivifier.exe", 1
if ( ErrorLevel ) {
	FileDelete, % A_ScriptDir "\Game Vivifier NewVersion.exe"
	IniWrite, 0,% iniFilePath, SETTINGS,AutoUpdate
	MsgBox,0x40010,, An error occured while updating!`nAuto-update was turned off for safety!
}
else Run, % A_ScriptDir "\Game Vivifier.exe"
ExitApp

