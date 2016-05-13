#SingleInstance Force
SetWorkingDir, A_ScriptDir
EnvGet, userprofile, userprofile
global userprofile
global programName := "Game Vivifier"
global iniFilePath := userprofile "\Documents\AutoHotKey\" programName "\Preferences.ini"
IniRead, programPID,% iniFilePath,SETTINGS,PID
IniRead, fileName,% iniFilePath,SETTINGS,FileName

if ( programPID != "ERROR" || programPID "" )
	Process, Close, %programPID%
Loop {
	Process, Close, %fileName%
	Process, Close, Game Vivifier.exe
	Process, Close, Game-Vivifier.exe
	sleep 100
	FileDelete,%  fileName
	FileDelete,% "Game Vivifier.exe"
	FileDelete,% "Game-Vivifier.exe"
	sleep 100
	if !(FileExist(fileName))
		if !(FileExist("Game Vivifier.exe"))
			if !(FileExist("Game Vivifier.exe"))
				break
}
sleep 1000
FileMove,% "gvNewver.exe",% "Game Vivifier.exe",1
if ( ErrorLevel ) {
	FileDelete, % "\gvNewver"
	IniWrite, 0,% iniFilePath, SETTINGS,AutoUpdate
	MsgBox,0x40010,, An error occured while updating!`nAuto-update was turned off for safety!
}
else {
	sleep 2000
	Run, % "Game Vivifier.exe"
}
ExitApp