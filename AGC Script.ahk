/*
	AGC Automatic Gama & Color Script by masato
	https://github.com/lemasato/AGC-Script
*/
AGCVersion := "1.3"

#SingleInstance Force

OnExit("ExitFunc")

;___Window Switch Detect___;
Gui +LastFound 
hWnd := WinExist()
DllCall( "RegisterShellHookWindow", UInt,Hwnd )
MsgNum := DllCall( "RegisterWindowMessage", Str,"SHELLHOOK" )
OnMessage( MsgNum, "ShellMessage" )

ShellMessage( wParam,lParam )
{
	WinGet, winEXE, ProcessName, ahk_id %lParam%
	If ( wParam=4 or wParam=32772 ) { ; 4=HSHELL_WINDOWACTIVATED | 32772=HSHELL_RUDEAPPACTIVATED
		WinGetTitle, winTitle, ahk_exe %winEXE%
		gammaColor := Check_Ini(winEXE)
		nv_Switch(nvHandler, gammaColor[1], gammaColor[2])
		}
}
;===============================

;======================================
;										AUTORUN
;											START
;======================================

;___Some variables___;
global iniFile, nvHandler, nvStatic, NVCPLPath
iniFile = %A_ScriptDir%\AGC_Config.ini
NVCPLPath = %A_ProgramFiles%\NVIDIA Corporation\Control Panel Client\nvcplui.exe
IniRead, nvStatic, %iniFile%, Settings, NVCPL.AdjustdesktopCtrl

;___Tray Menu___;
ifExist, %A_ScriptDir%\icon.ico
	Menu, Tray, Icon, %A_ScriptDir%\icon.ico,,0
Menu, Tray, Tip, Automatic Gama &&& Color Script
Menu, Tray, NoStandard
;~ Menu, Tray, Add, Settings, Tray_Settings
Menu, Tray, Add, Settings, Tray_Params
Menu, Tray, Add, Reload, Tray_Reload
Menu, Tray, Add, HELP!, Tray_Help
Menu, Tray, Add, 
Menu, Tray, Add, Hide, Tray_Hide
IniRead, x, %iniFile%, Settings, StartHidden
if ( x > 0 )
	Menu, Tray, Check, Hide
Menu, Tray, Add
Menu, Tray, Add, Exit, Tray_Exit

;___Functions calls___;
Create_Ini()
Run_NVCPL()
nvHandler := get_nvidia_handler()
TrayTip,,Ready!
return

;======================================
;										AUTORUN
;											END
;======================================

;___Functions___;
get_nvidia_handler() {
;			Retrieves the NVCPL's handler and returns it so we can use NVCPL if it's hidden.
	WinGet, nvPID, PID, ahk_exe nvcplui.exe
	WinGet, handler, ID, ahk_pid %nvPID%
	IniRead, hidden, %iniFile%, Settings, StartHidden
	if ( hidden != 0 )
		WinHide, ahk_exe nvcplui.exe
	return handler
}

nv_Switch(handler, gammaVal, colorVal) {
;			Sends the value retrived from the .ini to the NVCPL
	DetectHiddenWindows, On
	;~ ControlClick, %nvStatic%, ahk_id %handler%, , Left	; Static2 is the button pressed to enter the screen brightness/color settings
	;~ ControlClick ,%nvButton%, ahk_id %handler%, , Left	; Button4 is the button pressed to enable the custom settings
		PostMessage, 0x0405,0,% gammaVal -1,msctls_trackbar323, ahk_id %handler%	; Sends the Gamma value (minus one because we then press the right arrow to apply it) to the bar
			ControlSend,msctls_trackbar323, {Blind}{Right}, ahk_id %handler%	; press the right arrow to apply the value to the bar (it adds one, this is why we sent the gamma var value minus one)
		PostMessage, 0x0405,0,% colorVal -1,msctls_trackbar324, ahk_id %handler% ; same but for color
			ControlSend, msctls_trackbar324, {Blind}{Right}, ahk_id %handler% ; same but for color
	;~ ControlClick,Button9, ahk_id %handler%, , Left ; clicks on the apply button
}  

Create_Ini() {
;			creates the ini file and sets the non-existing values
	IniRead, x, %iniFile%, Settings, RunOnStartup
	if ( x = "ERROR" or x = "" )
		IniWrite, 0, %iniFile%, Settings, RunOnStartup	
	IniRead, x, %iniFile%, Settings, StartHidden
	if ( x = "ERROR" or x = "" )
		IniWrite, 1, %iniFile%, Settings, StartHidden	
	IniRead, x, %iniFile%, Settings, NVCPL.AdjustdesktopCtrl
	if ( x = "ERROR" or x = "" ) {
		x := First_Run("Adjust desktop color and settings", "Static")
		if x contains Static 
		{
			IniWrite, %x%, %iniFile%, Settings, NVCPL.AdjustdesktopCtrl
			;~ FileAppend, `n, %iniFile%
			Reload
		}
	}
	
	IniRead, x, %iniFile%, Default, Gamma
	if (x = "ERROR" or x = "" )
			IniWrite, 100, %iniFile%, Default, Gamma
	IniRead, x, %iniFile%, Default, Color
	if (x ="ERROR" or x = "" ) {
		IniWrite, 50, %iniFile%, Default, Color
		FileAppend, `n, %iniFile%
	}
}

Check_Ini(process) {
;			Retrieves the gamma/color values from the .ini and returns them for the nv_Switch function to use.
;			If no values have been set, it will apply the default ones
	IniRead, x, %iniFile%, %process%, Gamma
	if (x = "ERROR") ; if there is no settings specified for the app in the ini, applies the default ones
	{
		IniRead, gamma, %iniFile%, Default, Gamma
		IniRead, color, %iniFile%, Default, Color
	}
	else ; else applies custom settings
	{
		IniRead, gamma, %iniFile%, %process%, Gamma
		if gamma is not integer
			IniRead, gamma, %iniFile%, Default, Gamma
		
		IniRead, color, %iniFile%, %process%, Color
		if color is not integer
			IniRead, color, %iniFile%, Default, Color
	}
	return [gamma, color]
} 

Run_NVCPL() {
;			Runs the NVCPL and hides it if specified
	Loop, 2 {
	Process, Close, nvcplui.exe
	Process, WaitClose, nvcplui.exe
	Run, %NVCPLPath%, , Minimize
	WinWait, ahk_exe nvcplui.exe
	sleep 500
	}
	ControlClick, %nvStatic%, ahk_exe nvcplui.exe,,Left	; Static2 is the button pressed to enter the screen brightness/color settings
	sleep 500
	ControlClick, Button4, ahk_exe nvcplui.exe,,Left
}

First_Run(setting, controlName) {
;			Ask the user to help retrieving a control and returns it
global
Gui, NDR:Destroy
Gui, NFR:New, ,Welcome to AGC!
Gui, NFR:+AlwaysOnTop -SysMenu 
Gui, NFR:Add, text, x10 y10, Since it's your first time running the script, you have to go trough a few steps.`nThe NVIDIA Control Panel will now open.
Gui, NFR:Add, text, x10 y45, Please, click on %setting% then click on OK
Gui, NFR:Add, text, x10 y60 cBlue gNFR_Help xs, Here's some help (click)
Gui, NFR:Add, text, x10 y90, Control retrieved:
Gui, NFR:Add, Edit, x95 y87 vMyEdit WantReturn ReadOnly
Gui, NFR:Add, text, x10 y115, Example expected:
Gui, NFR:Add, Edit, x105 y113 vMyEdit2 ReadOnly, %controlName%
Gui, NFR:Add, Button, ys y100 w50 h30 gNFR_OK, OK
Gui, NFR:Show
Run, %NVCPLPath%
SetTimer, NFR_Refresh, 500
WinWait, Welcome to AGC!
WinWaitClose, Welcome to AGC!
return MyEdit
}
NFR_Help:
	Run, https://raw.githubusercontent.com/lemasato/AGC-Script/master/help.png
	return
NFR_OK:
	Gui, Submit, NoHide
	GuiControlGet, MyEdit	; control we need
	GuiControlGet, MyEdit2 ; var containing infos about it
	if MyEdit not contains %MyEdit2%
		msgbox, 262144, Warning!, The retrieved value does not seem to be valid! `nPlease make sure that it corresponds and try again.`n`nExpected value: %MyEdit2%`nRetrieved value: %MyEdit%
	else {
		SetTimer, NFR_Refresh, Off
		Gui, NFR:Submit
	}
	return
NFR_Refresh:
	MouseGetPos, , , winID
	WinGet, winEXE, ProcessName, ahk_id %winID%
	if ( winEXE = "nvcplui.exe" )
	{
		KeyWait, LButton, D T0.1
		If ( ErrorLevel = 1 ) ; timed out
			goto NFR_Refresh
		MouseGetPos, , , , datctrl
		GuiControl, NFR:, MyEdit, %datctrl%
	}
	return 
	
;___Tray Menu Labels___;

Tray_Params:
	global paramTitle
	winList := Tray_Params_getWindowsList()
	exe = Tray_Params_LoadPrefs()
	Gui, Param:Destroy
	Gui, Param:New, ,Settings
	Gui, Param: -MinimizeBox -MaximizeBox +AlwaysOnTop
	Gui, Param:Add, Checkbox, vRunOnStartup x10 y10, Run on startup?
	Gui, Param:Add, Checkbox, vStartHidden x10 y30, Hide nvidia control panel?
	Gui, Param:Add, Text, x231 y50, Select window
	Gui, Param:Add, DropDownList, x10 y65 Choose0 vparamTitle gTray_Params_LoadPrefs w500, %winList%
	Gui, Param:Add, Text, x90 y110, GAMMA
	Gui, Param:Add, Slider, x10 y125 w200 vGammaSlider Range30-280 ToolTip, 280
	Gui, Param:Add, Text, x402 y110, COLOR
	Gui, Param:Add, Slider, x320 y125 w200 vColorSlider Range0-100 Tooltip, 0
	Gui, Param:Add, Button, x241 y110 gTray_Params_Apply, Apply`nsettings
	Gui, Param:Add, Text,x230 y155 ,Default values:
	Gui, Param:Add, Edit, x180 y170 w45
	Gui, Param:Add, UpDown, vDefaultGamma Range30-280
	Gui, Param:Add, Edit, x305 y170 w45
	Gui, Param:Add, UpDown, vDefaultColor Range0-100
	IniRead, x, %iniFile%, Settings, RunOnStartup
		if ( x = 1 )
			GuiControl, Param:, RunOnStartup, 1
	IniRead, x, %iniFile%, Settings, StartHidden
		if ( x = 1 )
			GuiControl, Param:, StartHidden, 1
	IniRead, x, %iniFile%, Default, Gamma
	GuiControl, Param:, DefaultGamma, %x%
	IniRead, x, %iniFile%, Default, Color
	GuiControl, Param:, DefaultColor, %x%
	Gui, Param:Show
	

Tray_Params_Apply:
	Gui, Param:Submit, NoHide
	IniWrite, %RunOnStartup%, %iniFile%, Settings, RunOnStartup
	IniWrite, %StartHidden%, %iniFile%, Settings, StartHidden
	IniWrite, %DefaultGamma%, %iniFile%, Default, Gamma
	IniWrite, %DefaultColor%, %iniFile%, Default, Color
	If RunOnStartup 
		IfExist, %A_ScriptDir%\icon.ico
		FileCreateShortcut, %A_ScriptFullPath%, %A_Startup%\AGC.lnk, , , , %A_ScriptDir%\icon.ico
		else FileCreateShortcut, %A_ScriptFullPath%, %A_Startup%\AGC.lnk
	If !RunOnStartup
		FileDelete, %A_Startup%\AGC.lnk
	WinGet, exe, ProcessName, %paramTitle%
	if ( paramTitle != "" ) {
		IniWrite, %ColorSlider%, %iniFile%, %exe%, Color
		IniWrite, %GammaSlider%, %iniFile%, %exe%, Gamma
	}
return

Tray_Params_LoadPrefs() {
	Gui, Param:Submit, NoHide
	WinGet, exe, ProcessName, %paramTitle%
	IniRead, x, %iniFile%, %exe%, Gamma
	if ( x = "ERROR" or x = "" )
		IniRead, x, %iniFile%, Default, Gamma
	GuiControl, , GammaSlider, %x%
	IniRead, x, %iniFile%, %exe%, Color
	if ( x = "ERROR" or x = "" )
		IniRead, x, %iniFile%, Default, Color
		GuiControl, , ColorSlider, %x%
	return exe
}

Tray_Params_getWindowsList() {
	WinGet, windows, List 
	Loop, %windows%
	{
		WinGetTitle, title,% "ahk_id" windows%A_Index%
		WinGet, exe, ProcessName, %title%
		if ( exe != "explorer.exe" && exe != "autohotkey.exe" && exe != "nvcplui.exe" && exe != "" )
			winList.=title "|"
	}
	return winList
}

Tray_Help:
	Gui, Help:Destroy
	Gui, Help:New, ,AGC Help
	Gui, Help: -MinimizeBox -MaximizeBox +AlwaysOnTop
	Gui, Help:Add, text, ,Hello, thanks for using my script && welcome to AGC's Help!`n`nThis script sets Gamma && Color (Digital Vibrance) based on the active process.`nTo get started, right click on the tray icon then select [Settings].`nHere, you can decide whether should the script run on startup or if the Nvidia Control Panel should be hidden.`nYou can also select your favorite application to apply your custom Gamma/Vibrance preferences.`nWhen you're done, click on "Apply settings" && feel free to either select another application or close the GUI!
	Gui, Help: Add, text, cBlue gTray_Help_Thread,If you have any question, click here!
	Gui, Help: Add, text, cFA8C00 gTray_Help_Donate, If you like my work and feel generous, click here!
	Gui, Help: Add, text, cGreen, `nScript version: %AGCVersion%
	Gui, Help:Show
	return
Tray_Help_Thread:
	Run, http://ahkscript.org/boards/viewtopic.php?f=6&t=9455
	return
Tray_Help_Donate:
	Run, https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=E9W692RF9ZLYA
Tray_Reload:
	Reload
	return
Tray_Hide: 
	if WinExist("ahk_exe nvcplui.exe") {
		Menu, Tray, Check, Hide
		WinHide ahk_id %nvHandler%
	}
	else {
		Menu, Tray, Uncheck, Hide
		WinShow, ahk_id %nvHandler%
	}
	return
Tray_Exit:
	ExitApp
	return
	
;_____________________________________

ExitFunc() {
	Process, Close, nvcplui.exe
	Send {LCtrl UP}{LShift UP}{LAlt UP}{RCtrl UP}{RShift UP}{RAlt UP}
}