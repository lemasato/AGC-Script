/*
	AGC Automatic Gama & Color Script by masato
*/
AGCVersion := "1.2.0.1"

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
		GammaColor := Check_Ini(winEXE)
		nv_Switch(nvHandler, GammaColor[1], GammaColor[2])
		}
}

;___Some variables___;
global iniFile, nvHandler, nvStatic, NCPPath
iniFile = %A_ScriptDir%\AGC_Config.ini
NCPPath = %A_ProgramFiles%\NVIDIA Corporation\Control Panel Client\nvcplui.exe
IniRead, nvStatic, %iniFile%, Settings, NVIDIA.AdjustdesktopCtrl

;___Tray Menu___;
Menu, Tray, Icon, %A_ScriptDir%\icon.ico,,0
Menu, Tray, Tip, Automatic Gama &&& Color Script
Menu, Tray, NoStandard
Menu, Tray, Add, Settings, Tray_Settings
Menu, Tray, Add, Open .ini, Tray_Open_Ini
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
Run_NCP()
nvHandler := get_nvidia_handler()
TrayTip,,Ready!
return

;___Functions___;
get_nvidia_handler() {
;			Retrieves the NCP's handler and returns it so we can use NCP if it's hidden.
	WinGet, nvPID, PID, ahk_exe nvcplui.exe
	WinGet, handler, ID, ahk_pid %nvPID%
	IniRead, hidden, %iniFile%, Settings, StartHidden
	if ( hidden != 0 )
		WinHide, ahk_exe nvcplui.exe
	return handler
}

nv_Switch(handler, gammaVal, colorVal) {
;			Sends the value retrived from the .ini to the NCP
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
	
	IniRead, x, %iniFile%, Settings, NVIDIA.AdjustdesktopCtrl
	if ( x = "ERROR" or x = "" ) {
		x := NVIDIA_First_Run("Adjust desktop color and settings", "Static")
		if x contains Static 
		{
			IniWrite, %x%, %iniFile%, Settings, NVIDIA.AdjustdesktopCtrl
			FileAppend, `n, %iniFile%
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

	IniWrite, VALUE, %iniFile%, example.exe, Gamma
	IniWrite, VALUE, %iniFile%, example.exe, Color
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

Run_NCP() {
;			Runs the NCP and hides it if specified
	Loop, 2 {
	Process, Close, nvcplui.exe
	Process, WaitClose, nvcplui.exe
	Run, %NCPPath%, , Minimize
	WinWait, ahk_exe nvcplui.exe
	sleep 500
	}
	ControlClick, %nvStatic%, ahk_exe nvcplui.exe,,Left	; Static2 is the button pressed to enter the screen brightness/color settings
	sleep 500
	ControlClick, Button4, ahk_exe nvcplui.exe,,Left
}

Nvidia_First_Run(setting, controlName) {
;			Ask the user to help retrieving a control and returns it
global
Gui, NFR:+AlwaysOnTop -SysMenu 
Gui, NFR:Add, text, x10 y10, Since it's your first time running the script, you have to go trough a few steps.`nThe NVIDIA Control Panel will now open.
Gui, NFR:Add, text, x10 y45, Please, click on %setting% then click on OK
Gui, NFR:Add, text, x10 y60 cBlue gNFRHelp xs, Here's some help (click)
Gui, NFR:Add, text, x10 y90, Control retrieved:
Gui, NFR:Add, Edit, x95 y87 vMyEdit WantReturn ReadOnly
Gui, NFR:Add, text, x10 y115, Example expected:
Gui, NFR:Add, Edit, x105 y113 vMyEdit2 ReadOnly, %controlName%
Gui, NFR:Add, Button, ys y100 w50 h30 gNFROK, OK
Gui, NFR:Show, ,AGC First Run
Run, %NCPPath%
SetTimer, NFRRefresh, 500
WinWait, AGC First Run
WinWaitClose, AGC First Run
return MyEdit
}
NFRHelp:
	Run, %A_ScriptDir%\HELP.png
	return
NFROK:
	Gui, Submit, NoHide
	GuiControlGet, MyEdit	; control we need
	GuiControlGet, MyEdit2 ; var containing infos about it
	if MyEdit not contains %MyEdit2%
		msgbox, 262144, Warning!, The retrieved value does not seem to be valid! `nPlease make sure that it corresponds and try again.`n`nExpected value: %MyEdit2%`nRetrieved value: %MyEdit%
	else {
		SetTimer, NFRRefresh, Off
		Gui, NFR:Submit
	}
	return
NFRRefresh:
	MouseGetPos, , , winID
	WinGet, winEXE, ProcessName, ahk_id %winID%
	if ( winEXE = "nvcplui.exe" )
	{
		KeyWait, LButton, D T0.1
		If ( ErrorLevel = 1 ) ; timed out
			goto NFRRefresh
		MouseGetPos, , , , datctrl
		GuiControl, NFR:, MyEdit, %datctrl%
	}
	return 
	
;___Tray Menu Labels___;

Tray_Settings:
	Gui, Tray:Destroy
	IniRead, x, %iniFile%, Settings, RunOnStartup
	if ( x = 1 )
		Gui, Tray:Add, Checkbox, Checked vRunOnStartup, Run on startup?
	else Gui, Tray:Add, Checkbox, vRunOnStartup, Run on startup?

	IniRead, x, %iniFile%, Settings, StartHidden
	if ( x = 1 )
		Gui, Tray:Add, Checkbox, Checked vStartHidden, Hide the nvidia control panel?
	else Gui, Tray:Add, Checkbox, vStartHidden, Hide the nvidia control panel?

	Gui, Tray:Add, Button, xs y50 gTrayOK Default, OK
	Gui, Tray:Add, Button, x50 y50 gTrayCancel, Cancel
	Gui, Tray:Show
	return
TrayOK:
	Gui, Tray:Submit, NoHide
	Gui, Tray:Destroy
	If RunOnStartup or !RunOnStartup
		IniWrite, %RunOnStartup%, %iniFile%, Settings, RunOnStartup
	If RunOnStartup 
		FileCreateShortcut, %A_ScriptFullPath%, %A_Startup%\AGC.lnk, , , , %A_ScriptDir%\icon.ico
	If !RunOnStartup
		FileDelete, %A_Startup%\AGC.lnk
	If StartHidden or !StartHidden
		IniWrite, %StartHidden%, %iniFile%, Settings, StartHidden
	return
TrayCancel:
	Gui, Tray:Destroy
	return
Tray_Help:
	Gui, Help:Add, text, , Hello and thanks for using my script!`nHere, I will explain you a few things about how it works...`n`nThis script sets Gamma && Color (Digital Vibrance) based on the active window's exe name.`nTo get started and set your custom values, right click on the tray icon then select [Open .ini]`nOnce opened, you will be able to add your favorite games and sets their custom AGC values!`n(To know how, peek at the example!)`n`nYou can also change the default values that will be applied everytime a non-listed program is activated.`nGamma: 100 equals 1.00 on the slider.`nColor (Digital Vibrance): 50 equals 50`% on the slider.
	Gui, Help: Add, text, ,If you have any question, feel free to post on the ahkscript.org/autohotkey.com thread! (click)
	Gui, Help: Add, text, cBlue gHelp_Autohotkeycom, Click here for the ahkscript.org thread
	Gui, Help: Add, text, cBlue gHelp_Ahkscriptorg, Or here for the autohotkey.com one
	Gui, Help: Add, text, xs cGreen, `nScript version: %AGCVersion%
	Gui, Help:Show
	return
Help_Autohotkeycom:
	Run, http://ahkscript.org/boards/
	return
Help_Ahkscriptorg:
	Run, http://www.autohotkey.com/board/topic/
GuiClose:
	Gui, Destroy
	return
Tray_Open_Ini:
	Run, %iniFile%
	return
Tray_Reload:
	Reload
	return
Tray_Hide() {
;~ global nvHandler
	if WinExist("ahk_exe nvcplui.exe") {
		Menu, Tray, Check, Hide
		WinHide ahk_id %nvHandler%
	}
	else {
		Menu, Tray, Uncheck, Hide
		WinShow, ahk_id %nvHandler%
	}
}
Tray_Exit:
	ExitApp
	return
	
ExitFunc(ExitReason, ExitCode) {
	Process, Close, nvcplui.exe
	Send {LCtrl UP}{LShift UP}{LAlt UP}{RCtrl UP}{RShift UP}{RAlt UP}
}