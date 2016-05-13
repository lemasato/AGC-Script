/* 
	Game Vivifier by masato
	Allows NVIDIA users to have custom gamma/vibrance profiles for their game
	https://autohotkey.com/boards/viewtopic.php?t=9455
	https://github.com/lemasato/Game-Vivifier
*/
OnExit("Exit_Func")

#SingleInstance Force
SetWorkingDir, %A_ScriptDir%
EnvGet, userprofile, userprofile
global userprofile
;===============================

;___Some variables___;
global programVersion := "2.0.4" , programName := "Game Vivifier"
global iniFilePath := userprofile "\Documents\AutoHotKey\" programName "\Preferences.ini"
global nvcplHandler, nvcplPath, nvStatic, programPID
programPID := DllCall("GetCurrentProcessId")
IniWrite,% programPID,% iniFilePath,SETTINGS,PID

;___Tray Menu___;
if FileExist("icon.ico") {
	sleep 10
	Menu, Tray, Icon, icon.ico,,0
}
Menu, Tray, Tip, %programName%
Menu, Tray, NoStandard
Menu, Tray, Add, Settings, Tray_Params
Menu, Tray, Add, About?, Tray_About
Menu, Tray, Add, 
Menu, Tray, Add, Hide NVCPL, Tray_Hide
IniRead, x, %iniFilePath%, SETTINGS, StartHidden
if ( x > 0 )
	Menu, Tray, Check, Hide NVCPL
Menu, Tray, Add
Menu, Tray, Add, Reload, Tray_Reload
Menu, Tray, Add, Close, Tray_Exit

;___Creating .ini Dir___;
if !( InStr(FileExist("\Documents\AutoHotkey"), "D") )
	FileCreateDir, % userprofile "\Documents\AutoHotkey"
if !( InStr(FileExist("\Documents\AutoHotkey\" programName ), "D") )
	FileCreateDir, % userprofile "\Documents\AutoHotkey\" programName

;___Functions calls___;
Check_Update(autoUpdate)
nvcplHandler := Run_NVCPL()
iniSettingsArray := Get_Ini_Settings()
autoUpdate := iniSettingsArray[1], nvStatic := iniSettingsArray[2], iniSettingsArray := ""
TrayTip,% programName " v" programVersion,Right click on the tray icon then`n>> [Settings] for profiles.`n>> [About?] for help.

;___Window Switch Detect___;
Gui +LastFound 
Hwnd := WinExist()
DllCall( "RegisterShellHookWindow", UInt,Hwnd )
MsgNum := DllCall( "RegisterWindowMessage", Str,"SHELLHOOK" )
OnMessage( MsgNum, "ShellMessage" )
return

ShellMessage( wParam,lParam )
{
	If ( wParam=4 or wParam=32772 ) { ; 4=HSHELL_WINDOWACTIVATED | 32772=HSHELL_RUDEAPPACTIVATED
		WinGet, winEXE, ProcessName, ahk_id %lParam%
		userPrefs := Get_Preferences(winEXE)
		Switch(winEXE, winTitle, userPrefs[1], userPrefs[2], userPrefs[3], userPrefs[4])
		}
	}

;======================================
;										FUNCTIONS
;======================================

Switch(process, title, gVal, cVal, gDef, cDef) {
;			Apply gamma/vibrance preferences.
;			Values are minus one because we press RIGHT (+1) to register the message.
;			If fullscreen application is detected, send the message 10 times with 2s delay.
	DetectHiddenWindows, On
	if !( WinExist("ahk_id " nvcplHandler ) ) {
		Sleep 1000
		Reload
	}
	PostMessage, 0x0405,0,% gVal -1,msctls_trackbar323, ahk_id %nvcplHandler%
	ControlSend,msctls_trackbar323, {Blind}{Right}, ahk_id %nvcplHandler%
	PostMessage, 0x0405,0,% cVal -1,msctls_trackbar324, ahk_id %nvcplHandler%
	ControlSend, msctls_trackbar324, {Blind}{Right}, ahk_id %nvcplHandler%
	isFullscreen := Is_Window_Fullscreen( process, title )
	if ( isFullscreen ) && ( ( gVal != gDef ) || ( cVal != cDef ) )
	{	; Fixes the issue where the default values would be set after a few seconds when the game resolution is different from desktop resolution
		timeOut := A_Sec + 10 , delay := A_Sec + 1 , i := 0
		Loop
		{
			if ( timeOut > 59 ) ; set correctly if higher than 59
				if ( A_Sec < 10 )
					timeOut -= 60
			if ( A_Sec > timeOut ) OR ( ( A_Sec < 10 ) AND ( timeOut = 59 ) ) ; break the loop once specified time was reached
				break
			If !( WinActive( title " ahk_exe " process) ) ; break the loop if the window isn't active anymore
				break
			if ( A_Sec >= delay ) OR ( ( A_Sec < 59 ) AND ( delay > 59 ) ) ; repeat every 2secs
			{
				delay := A_Sec + 2
				If Mod(delay, 2)=0
				{
					;		Make sure the value is sent by moving the slider a tick right, then two tick right
					PostMessage, 0x0405,0,% gVal -1,msctls_trackbar323, ahk_id %nvcplHandler%
					ControlSend,msctls_trackbar323, {Blind}{Right}, ahk_id %nvcplHandler%
					PostMessage, 0x0405,0,% cVal -1,msctls_trackbar324, ahk_id %nvcplHandler%
					ControlSend, msctls_trackbar324, {Blind}{Right}, ahk_id %nvcplHandler%
				}
				else
				{
					PostMessage, 0x0405,0,% gVal -2,msctls_trackbar323, ahk_id %nvcplHandler%
					ControlSend,msctls_trackbar323, {Blind}{Right 2}, ahk_id %nvcplHandler%
					PostMessage, 0x0405,0,% cVal -2,msctls_trackbar324, ahk_id %nvcplHandler%
					ControlSend, msctls_trackbar324, {Blind}{Right 2}, ahk_id %nvcplHandler%
				}
			}
			else sleep 100
		}
	}
	DetectHiddenWindows, Off
}  

Get_Ini_Settings() {
;			Creates the ini file, sets the broken/unexistent values
;				Return the settings
	IniRead, x, %iniFilePath%, SETTINGS, RunOnStartup
	if ( x = "ERROR" or x = "" )
		IniWrite, 0, %iniFilePath%, SETTINGS, RunOnStartup
	
	IniRead, x, %iniFilePath%, SETTINGS, StartHidden
	if ( x = "ERROR" or x = "" )
		IniWrite, 1, %iniFilePath%, SETTINGS, StartHidden
	
	IniRead, x, %iniFilePath%, DEFAULT, Gamma
	if (x = "ERROR" or x = "" )
			IniWrite, 100, %iniFilePath%, DEFAULT, Gamma

	IniRead, x, %iniFilePath%, DEFAULT, Vibrance
	if (x ="ERROR" or x = "" )
		IniWrite, 50, %iniFilePath%, DEFAULT, Vibrance
	
	
	IniRead, autoUpdate,% iniFilePath,SETTINGS,AutoUpdate
	if ( autoUpdate = "ERROR" || x = "" )
		IniWrite, 0,% iniFilePath,SETTINGS,AutoUpdate
	
;	Retrieving the control ID
	IniRead, nvStatic,% iniFilePath,SETTINGS,AdjustDesktopCtrl
	IniRead, nvStaticText,% iniFilePath,SETTINGS,AdjustDesktopCtrlText
	if ( nvStatic = "ERROR" || nvStatic = "" || nvStaticText = "ERROR" || nvStaticText = "" ) {
		i := 0
		WinShow, ahk_id %nvcplHandler%
		WinWait, ahk_id %nvcplHandler%
		Loop {
			ControlGetText, ctrlText, Static%i%, ahk_id %nvcplHandler%
			if ( ctrlText = "Régler les paramètres des couleurs du bureau" || ctrlText = "Adjust desktop color settings" || i > 10 )
				break
			i++
		}
		if ( i < 10 ) { ; Control found automatically
			IniWrite,Static%i%,% iniFilePath,SETTINGS,AdjustDesktopCtrl
			IniWrite,% ctrlText,% iniFilePath,SETTINGS,AdjustDesktopCtrlText
		}
		else {
			nvStaticArray := Get_Control_From_User("Adjust Desktop Color Settings")
			nvStatic := nvStaticArray[1], nvStaticText := nvStaticArray[2]
			IniWrite,% nvStatic,% iniFilePath,SETTINGS,AdjustDesktopCtrl
			IniWrite,% nvStaticText,% iniFilePath,SETTINGS,AdjustDesktopCtrlText
		}
	}

	IniRead, hidden, %iniFilePath%, SETTINGS, StartHidden
	if ( hidden = 1 )
		WinHide, ahk_id %nvcplHandler%
	return [autoUpdate, nvStatic]
}

Get_Preferences(process) {
;			Retrieves the preferences from the .ini, returns them
;			If no preferences have been set, default one will be returned
	IniRead, x, %iniFilePath%, %process%, Gamma
	IniRead, x2, %iniFilePath%, %process%, Vibrance
	if ( x = "ERROR" ) OR ( x2 = "ERROR" ) ; if no settings specified applies the default ones
	{
		IniRead, gamma, %iniFilePath%, DEFAULT, Gamma
		IniRead, color, %iniFilePath%, DEFAULT, Vibrance
	}
	else ; else applies custom settings
	{
		IniRead, gamma, %iniFilePath%, %process%, Gamma
		if gamma is not integer
			IniRead, gamma, %iniFilePath%, DEFAULT, Gamma
		
		IniRead, color, %iniFilePath%, %process%, Vibrance
		if color is not integer
			IniRead, color, %iniFilePath%, DEFAULT, Vibrance
	}
	IniRead, gammaDef, %iniFilePath%, DEFAULT, Gamma
	IniRead, colorDef, %iniFilePath%, DEFAULT, gammaDef
	if ( gammaDef = "ERROR" || gammaDef = "" )
		gammaDef := 100
	if ( colorDef = "ERROR" || colorDef ="" )
		colorDef := 50		
	if ( gamma = "ERROR" || gamma = "" )
		gamma := 100
	if ( color = "ERROR" || color ="" )
		color := 50
	return [gamma, color, gammaDef, colorDef]
} 

Run_NVCPL() {
;			Retrieve the NVCPL location and runs it
;			If unable to find it, ask the user to point its location
	IniRead, nvcplPath,% iniFilePath,SETTINGS,Path
	if ( nvcplPath = "ERROR" || nvcplPath = "" ) {
		EnvGet, progFiles, ProgramW6432
		if ( progFiles = )
			EnvGet, progFiles, ProgramFiles
		nvcplPath := progFiles "\NVIDIA Corporation\Control Panel Client\nvcplui.exe"
	}
	if !( FileExist( nvcplPath ) ) {
		FileSelectFile, nvcplPath, 3, %progFiles%, Please go to NVIDIA Corporation\Control Panel Client\nvcplui.exe, nvcplui.exe
		if ( ErrorLevel = 1 )
			Reload
	}
	IniWrite, % nvcplPath,% iniFilePath, SETTINGS, Path
	Process, Close, nvcplui.exe
	Process, WaitClose, nvcplui.exe
	Run, %nvcplPath%, ,Min ,nvPID
	WinWait, ahk_pid %nvPID%
	WinGet, nvcplHandler, ID, ahk_pid %nvPID%
	WinShow, ahk_id %nvcplHandler%
	IniRead, nvStatic,% iniFilePath,SETTINGS,AdjustDesktopCtrl
	IniRead, nvStaticText,% iniFilePath,SETTINGS,AdjustDesktopCtrlText
	if ( nvStatic = "ERROR" || nvStatic = "" || nvStaticText = "ERROR" || nvStaticText = "" ) ; If empty, we return so Get_Ini_Settings() will handle it
		return nvcplHandler
	ControlGetText, ctrlText,% nvStatic, ahk_id %nvcplHandler%
	if ( nvStaticText != ctrlText ) {
		IniDelete,% iniFilePath,SETTINGS,AdjustDesktopCtrl
		IniDelete,% iniFilePath,SETTINGS,AdjustDesktopCtrlText
		Reload
	}
	ControlClick, %nvStatic%, ahk_id %nvcplHandler%,,Left	; "Adjust Desktop Color Settings" button
	sleep 100
	ControlClick, Button4, ahk_id %nvcplHandler%,,Left ; "Use NVIDIA settings" button
	return nvcplHandler
}
	
Is_Window_FullScreen(process, title) {
;			Detects if the window is fullscreen
;			 by checking its style and size
	hwnd := WinExist( title " ahk_exe " process )
	WinGet style, Style, ahk_id %hwnd%
	WinGetPos, , , w, h, ahk_id %hwnd%
	state := ( ( style & 0x20800000 ) or h < A_ScreenHeight or w < A_ScreenWidth ) ? false : true
	return state
}

Check_Update(auto) {
;			Check for an update online, and ask the user if he wants to update now
;			If Auto-Update is On, automatically download the update
;			It works by downloading both the new version and the auto-updater
;				then closing the current instancie of the script and renaming the new version
	static
	if programVersion contains beta
		return
	updaterPath := A_ScriptDir "\Game Vivifier Updater.exe"
	newVersionPath := A_ScriptDir "\Game Vivifier NewVersion.exe"
	if (FileExist(updaterPath))
		FileDelete,% updaterPath
	if (FileExist(newVersionPath))
		FileDelete % newVersionPath
	
	ComObjError(0)
	whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	whr.Open("GET", "https://raw.githubusercontent.com/lemasato/Game-Vivifier/master/version.txt", true)
	whr.Send()
	; Using 'true' above and the call below allows the script to remain responsive.
	whr.WaitForResponse(3) ; 3 seconds
	if ( whr.ResponseText != "" )
		newVersion := whr.ResponseText
	else newVersion := programVersion ; couldn't reach the file, cancel update
	StringReplace, newVersion, newVersion, `n,,1 ; remove the 2nd line
	if ( programVersion != newVersion ) {
		if ( auto = 1 )
			GoSub YesUpdate
		else {		
			Gui, Update:Destroy
			Gui, Update:New, +AlwaysOnTop +SysMenu -MinimizeBox -MaximizeBox +OwnDialogs +HwndUpdateGuiHwnd,% "Update! v" newVersion
			Gui, Update:Default
			Gui, Add, Text, x10 y10,A new version was found!`nWould you like to update now?
			Gui, Add, Button, x10 y50 w70 h40 gYesUpdate,Yeah`nDo it now!
			Gui, Add, Button, x95 y50 w70 h40 gNoUpdate,Nope`nNext time?
			Gui, Add, Button, x10 y100 w150 h40 gDownloadPage,Just take me`nto the download page
			Gui, Add, CheckBox, x25 y150 vautoUpdate,Update automatically`n       from now on?
			Gui, Show
			WinWait, ahk_id %UpdateGuiHwnd%
			WinWaitClose, ahk_id %UpdateGuiHwnd%
		}
	}
	return

	YesUpdate:
		Gui, Submit
		if ( autoUpdate )
			IniWrite, 1,% iniFilePath,SETTINGS,AutoUpdate
		UrlDownloadToFile, https://raw.githubusercontent.com/lemasato/Game-Vivifier/master/Updater.exe,% updaterPath
		UrlDownloadToFile, https://raw.githubusercontent.com/lemasato/Game-Vivifier/master/Game Vivifier.exe, % A_ScriptDir "\Game Vivifier NewVersion.exe"
		Loop {
			if FileExist(updaterPath)
				if FileExist(A_ScriptDir "\Game Vivifier NewVersion.exe")
					break
			sleep 1000
		}
		IniWrite,% A_ScriptName,% iniFilePath,SETTINGS,FileName
		sleep 1000
		Run, % updaterPath
		Process, close, %programPID%
	return

	NoUpdate:
		Gui, Submit
		if ( autoUpdate )
			IniWrite, 1,% iniFilePath,SETTINGS,AutoUpdate
	return
	
	DownloadPage:
		Gui, Submit
		Run, https://github.com/lemasato/Game-Vivifier/releases/latest
	return
}

#SingleInstance Force
Get_Control_From_User("Adjust desktop color settings")

Get_Control_From_User(ctrlName) {
;			Ask the user to click on a specific button so we can retrieve its control ID
	static
	global ctrlRetrieved, ctrlRetrievedText
	supportedLanguages := "[EN/FR]"
	Gui, NFR:Destroy
	Gui, NFR:New, +AlwaysOnTop +SysMenu -MinimizeBox -MaximizeBox +OwnDialogs +LabelNFR_ +hwndGuiNFRHwnd,% "ERROR"
	Gui, NFR:Default
	Gui, Add, text, x10 y10, Couldn't retrieve the control ID for "%ctrlName%"! You will have to manually click on it.
	Gui, Add, text, x10 y25, This error usually happens when your NVCPL's language is different than %supportedLanguages%
	Gui, Add, text, x10 y40, Please, wait for the NVIDIA Control Panel to open then click on "%ctrlName%"
	Gui, Add, text, x10 y55 cBlue gNFR_Help xs, >> Click for an helpful screenshot, in case you feel lost <<
	Gui, Add, text, x10 y85, Control retrieved: 
	Gui, Add, Edit, x95 y82 vctrlRetrieved WantReturn ReadOnly
	Gui, Add, text, x10 y115, Expected (example): 
	Gui, Add, Edit, x105 y112 ReadOnly, Static2
	Gui, Add, text, x10 y145 cBlue gTray_About_Thread,If you wish to help make %programName% easier for others`nplease post the content of the box below on the ahkscript.org thread! (Click)
	Gui, Add, Edit, x10 y177 w365 vctrlRetrievedText ReadOnly
	Gui, Add, Button, x440 y90 w60 h40 gNFR_OK, OK
	Gui, Show
	WinShow, ahk_id %nvcplHandler%
	WinRestore, ahk_id %nvcplHandler%
	SetTimer, NFR_Refresh, 100
	WinWait, ahk_id %GuiNFRHwnd%
	WinWaitClose, ahk_id %GuiNFRHwnd%
	WinHide, ahk_id %nvcplHandler%
	return [ctrlRetrieved, ctrlRetrievedText]
	
	NFR_Close:
		Reload
	return
	
	NFR_Escape:
		Reload
	return

	NFR_Help:
		Run, https://raw.githubusercontent.com/lemasato/Game-Vivifier/master/Screenshots/Nvidia`%20Control`%20Panel.png
	return
	
	NFR_OK:
		Gui, Submit, NoHide
		GuiControlGet, ctrlRetrieved
		if ctrlRetrieved contains Static
		{
			SetTimer, NFR_Refresh, Off
			Gui, Submit
		}
	return
	
	NFR_Refresh:
		MouseGetPos, , , winHandler
		WinGet, winEXE, ProcessName, ahk_id %winHandler%
		if ( winEXE = "nvcplui.exe" )
		{
			KeyWait, LButton, D
			MouseGetPos, , , , ctrlName
			ControlGetText, ctrlText,% ctrlName, ahk_id %winHandler%
			if ctrlName contains Static
			{
				GuiControl, NFR:, ctrlRetrieved,% ctrlName
				GuiControl, NFR:, ctrlRetrievedText,% ctrlText
			}
		}
	return 
}


Exit_Func(ExitReason, ExitCode) {
	if ExitReason not in Logoff,Shutdown,Reload,Single
    {
        MsgBox, 4, % programName, % "Do you really wish to close " programName "?"
        IfMsgBox, No
            return 1  ; OnExit functions must return non-zero to prevent exit.
		Process, Close, nvcplui.exe
    }
}
	
;===================
;========== Tray Menu


Tray_Params:
	;		Top Settings
	Gui, Settings:Destroy
	Gui, Settings:New, +AlwaysOnTop +SysMenu -MinimizeBox -MaximizeBox +OwnDialogs +LabelSettings_,% programName " Settings"
	Gui, Settings:Default
	Gui, Add, CheckBox, x10 y10 vrunOnStartup, Run on computer startup?
	GuiControl, Settings:,runOnStartup,1
	Gui, Add, Button, x541 y3 w50 h30 vhelpMe,Help?
	;		Left and Right boxes
	Gui, Add, ListBox, x10 y35 w250 h300 vleftListItem,%wList%
	Gui, Add, ListBox, x340 y35 w250 h300 vrightListItem gRight_List_Event
	;		Middle Buttons
	Gui, Add, Button, x260 y130 w80 h30 gRight_Arrow,>
	Gui, Add, Button, x260 y160 w80 h40 gRefresh_Both_Lists, Refresh`nPrograms List
	Gui, Add, Button, x260 y200 w80 h30 gLeft_Arrow,<
	Gui, Add, Button, x260 y35 w80 gDetect_Hidden, Hidden`nWindows`n>> OFF <<
	;~ Gui, Add, Checkbox, x272 y35 gDetect_Hidden vdetectHidden, Detect`nHidden?
	Gui, Add, Button, x260 y285 w80 h40 gApply_Settings,Apply`nSettings
	;		Gamma Slider
	Gui, Add, Text, x103 y334, Gamma
	Gui, Add, Slider, x145 y330 w210 Range30-280 vgammaValue gSlider_Event Line5 Page5 NoTicks AltSubmit, 100
	Gui, Add, Edit, x355 y330 w45 gSlider_Event vgammaEdit, 100
	Gui, Add, UpDown, gSlider_Event Range30-280, 100
	Gui, Add, Text, x410 y334, Default:
	Gui, Add, Edit, x453 y330 w45 vgammaDefault, 100
	Gui, Add, UpDown, Range-30-280, 100
	;		Vibrance Slider
	Gui, Add, Text, x103 y359, Vibrance
	Gui, Add, Slider, x145 y355 w210 Range0-100 vvibranceValue gSlider_Event Line5 Page5 NoTicks AltSubmit, 50
	Gui, Add, Edit, x355 y355 w45 gSlider_Event vvibranceEdit, 50
	Gui, Add, UpDown, gSlider_Event Range0-100, 50
	Gui, Add, Text, x410 y359, Default:
	Gui, Add, Edit, x453 y355 w45 vvibranceDefault, 100
	Gui, Add, UpDown, Range-0-100, 50

	GoSub Refresh_Both_Lists
	Gui, Show, AutoSize
	OnMessage(0x200,"WM_MOUSEMOVE", 1)
return

Right_List_Event:
;			Triggers upon selecting an item from the right list
;			Applies the correct values to the slider/editbox depending on the process
	Gui, Submit, NoHide
	IniRead, gammaValue,% iniFilePath,% rightListItem,Gamma
	IniRead, vibranceValue,% iniFilePath,% rightListItem,Vibrance
	if ( gammaValue = "ERROR" )
		gammaValue := gammaDefault
	if ( vibranceValue = "ERROR" )
		vibranceValue := vibranceDefault
	GuiControl, Settings:,gammaValue,% gammaValue
	GuiControl, Settings:,gammaEdit,% gammaValue
	GuiControl, Settings:,vibranceValue,% vibranceValue
	GuiControl, Settings:,vibranceEdit,% vibranceValue
	rightListExe := rightListItem
return


Slider_Event:
;			Make sure the slider and the editbox match the same value
	Gui, Submit, NoHide
	 if ( A_GuiControl = "gammaValue" )
		GuiControl, Settings:,gammaEdit,%gammaValue%
	else if ( A_GuiControl = "gammaEdit" )
		GuiControl, Settings:,gammaValue,%gammaEdit%
	else if ( A_GuiControl = "vibranceValue" )
		GuiControl, Settings:,vibranceEdit,%vibranceValue%
	else if ( A_GuiControl = "vibranceEdit" )
		GuiControl, Settings:,vibranceValue,%vibranceEdit%
return


Detect_Hidden:
;			Warning that opens upon ticking the box
	detectHidden := !detectHidden
	Gui, Submit, NoHide
	if ( detectHidden ) {
		GuiControl, Settings:,%A_GuiControl%,Hidden`nWindows`n>> ON <<
		MsgBox, 0x40030,%A_SPace%,----------------------------------------------`n                    (Use with cautious!)`n          Allow to detect hidden windows.`n`n        Only use it as a last ressort solution,`n  when your game doesn't appear in the list!`n----------------------------------------------
	}
	else GuiControl, Settings:,%A_GuiControl%,Hidden`nWindows`n>> OFF <<
	GoSub, Refresh_Both_Lists
return


Right_Arrow:
;			Add the item to the right list
;			Write the process info to the ini file, apply the default value
	Gui, Submit, NoHide
	if ( leftListItem = "" )
		return

	winArray := StrSplit(leftListItem, " // ")
	winExe := winArray[1]
	IniRead, allSections,% iniFilePath
	if allSections not contains %winExe%
	{
		IniWrite,% gammaDefault,% iniFilePath,% winExe,Gamma
		IniWrite,% vibranceDefault,% iniFilePath,% winExe,Vibrance
	}
	GoSub Refresh_Both_Lists
return


Left_Arrow:
;			Remove the item from the right list
;			Delete its entry name
	Gui, Submit, NoHide
	if ( rightListItem = "" )
		return
	IniDelete,% iniFilePath,% rightListItem
	GoSub Refresh_Both_Lists
return


Refresh_Both_Lists:
;			Refresh both lists
;			If the box was ticked, detect hidden windows too 
	Gui, Submit, NoHide
	if ( detectHidden )
		DetectHiddenWindows, On
	GoSub Refresh_Left_List
	GoSub Refresh_Right_List
	GoSub Right_List_Event
return


Refresh_Left_List:
;			Refresh the content from the left list
;			Retrieve all the current windows and put them into a list, sorted alphabetically
	WinGet, allWindows, List
	wList := "" ; Make sure to empty the list
	Loop, %allWindows% 
	{ 
		WinGetTitle, wTitle, % "ahk_id " allWindows%A_Index%
		WinGet, wExe, ProcessName, %wTitle%
		if ( wExe != "explorer.exe" && wExe != "autohotkey.exe" && wExe != "nvcplui.exe" && wExe != A_ScriptName && wExe != "" ) ; Ignore these programs
			if wList not contains % wExe " // " wTitle "|"	; avoid duplicate
				wList .= wExe " // " wTitle "|"
	} 
	StringReplace, wList, wList,|,`n,1	; Replace list separators by a linefeed
	Sort, wList	; Sort the list alphabetically
	StringReplace, wList, wList,`n,|,1	; Put the list back in place
	GuiControl, Settings:,leftListItem,|%wList%
return


Refresh_Right_List:
;			Refresh the content of the right list
;			Retrieve all the sections from the ini file and put them into a list, sorted alphabetically
	rightListContent := "|"	; make sure to clear the content from the list
	IniRead, allSections,% iniFilePath	; retrieve all sections
	allSectionsArray := StrSplit(allSections, "`n")	; transform the linefeed into array
	for index, element in allSectionsArray ; for every section name
	{
		if ( element != "GENERAL" && element != "DEFAULT" && element != "SETTINGS" ) { ; if the section is not part of those
			rightListContent .= element "|" ; add it in the list as a simple process
		}
	}
	StringReplace, rightListContent, rightListContent,|,`n,1	; Replace list separators by a linefeed
	Sort, rightListContent	; Sort the list alphabetically
	StringReplace, rightListContent, rightListContent,`n,|,1	; Put the list back in place
	GuiControl, Settings:,rightListItem,% rightListContent
return


Apply_Settings:
;			Write all settings into the ini file
;			Create shortcut ir runOnStartup is ticked
	Gui, Submit, NoHide
	IniWrite, % runOnStartup, % iniFilePath,SETTINGS,RunOnStartup
	IniWrite, % gammaDefault, % iniFilePath,DEFAULT,Gamma
	IniWrite, % vibranceDefault, % iniFilePath,DEFAULT,Vibrance
	if ( runOnStartup ) {
		if ( FileExist( A_ScriptDir "\icon.ico" ) ) {
			fileName := StrSplit(A_ScriptName,.)
			if fileName[2] contains ahk
				FileCreateShortcut, % A_ScriptFullPath, % A_Startup "\" programName ".lnk", , , , % A_ScriptDir "\icon.ico"
		}
		else FileCreateShortcut, % A_ScriptFullPath, % A_Startup "\" programName ".lnk"
	}
	if !( runOnStartup )
		FileDelete, % A_Startup "\" programName ".lnk"
	if ( rightListExe != "" ) {
		IniWrite,% gammaValue,% iniFilePath,% rightListExe,Gamma
		IniWrite,% vibranceValue,% iniFilePath,% rightListExe,Vibrance
	}
return

Settings_Close:
Gui, Settings:Destroy
OnMessage(0x200,"WM_MOUSEMOVE", 0)
ToolTip
return

Settings_Escape:
Gui, Settings:Destroy
OnMessage(0x200,"WM_MOUSEMOVE", 0)
ToolTip
return

WM_MOUSEMOVE()
{
 local controlName
 MouseGetPos,,,, controlName
 if ( A_GuiControl = "helpMe" )
 ToolTip The left list are the currently running programs. The right one are your favourites.`nIf you wish to add a program to your favourite`, select the program from the left list and click the arrow facing right ">"`nSelect your newly added favourite and move the sliders to suit your needs`, then click on "Apply Settings"`nRemoving a program from your favourites can be done by selecting it then clicking the other arrow facing left "<"
 else ToolTip
sleep 100
}

Tray_About() {
	Gui, About:Destroy
	Gui, About:New, +AlwaysOnTop +SysMenu -MinimizeBox -MaximizeBox +OwnDialogs,% programName " by masato"
	Gui, About:Default
	Gui, Add, Text, cGreen x320 y10,v%programVersion%
	Gui, Add, Text, x10 y10,Hello! Thank you for using %programName%!
	Gui, Add, Text, x10 y35,%programName% sets Gamma and Digital Vibrance based on the active process.`nTo get started, right click on the tray icon then select [Settings].
	Gui, Add, Text, x10 y75,Select your favorite game from the left list and click on the ">" button.`nThen, select your game from the right list, set your preferences`n   by moving the sliders and click on [Apply settings].`n
	Gui, Add, Text, x10 y125 cBlue gTray_About_Thread,>> Visit the ahkscript.org thread <<
	if !( FileExist( A_Temp "\paypaldonatebutton.png" ) )
		UrlDownloadToFile, https://www.paypalobjects.com/en_US/i/btn/btn_donate_SM.gif, % A_Temp "\paypaldonatebutton.png"
	if ( ErrorLevel )
		Gui, Add, Button, x295 y125 gTray_About_Donate, Donate
	Gui, Add, Picture, x290 y122 gTray_About_Donate,% A_Temp "\paypaldonatebutton.png"
	Gui, Show, AutoSize
}
Tray_About_Thread:
	Run, https://autohotkey.com/boards/viewtopic.php?t=9455
return
Tray_About_Donate:
	Run, https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=E9W692RF9ZLYA
return
Tray_Reload:
	Reload
return
Tray_Hide: 
	if WinExist("ahk_exe nvcplui.exe") {
		Menu, Tray, Check, Hide NVCPL
		WinHide ahk_id %nvcplHandler%
	}
	else {
		Menu, Tray, Uncheck, Hide NVCPL
		WinShow, ahk_id %nvcplHandler%
	}
return
Tray_Exit:
	ExitApp
return

;																				========== Tray Menu
;																				===================