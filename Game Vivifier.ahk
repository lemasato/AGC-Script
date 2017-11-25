/* 	Game Vivifier by lemasato
	Allows NVIDIA users to have custom gamma/vibrance profiles for their applications

	https://autohotkey.com/boards/viewtopic.php?t=9455
	https://github.com/lemasato/Game-Vivifier
*/

#Warn LocalSameAsGlobal, StdOut
OnExit("Exit_Func")
#SingleInstance Off
#Persistent
#NoEnv
SetWorkingDir, %A_ScriptDir%
FileEncoding, UTF-8 ; Required for cyrillic characters
#KeyHistory 0
SetWinDelay, 0
DetectHiddenWindows, Off
ListLines, Off

if ( !A_IsCompiled && FileExist(A_ScriptDir "\icon.ico") )
	Menu, Tray, Icon,% A_ScriptDir "\icon.ico"
Menu,Tray, Tip,Game Vivifier
Menu,Tray,NoStandard
Menu,Tray,Add,Close,Exit_Func

ShellMessage_State(1)
Start_Script()
Return

Start_Script() {
/*
*/
	global ProgramValues 				:= {}
	global ProgramSettings 				:= {}
	global NVIDIA_Values				:= {}
	global GameProfiles 				:= {}
;	main infos
	ProgramValues.Name 					:= "Game Vivifier"
	ProgramValues.Version 				:= "2.1.3"
	ProgramValues.Branch 				:= "master"
	ProgramValues.Github_User 			:= "lemasato"
	ProgramValues.GitHub_Repo 			:= "Game-Vivifier"
;	folders
	ProgramValues.Local_Folder 			:= A_MyDocuments "\AutoHotkey\" ProgramValues.Name
	ProgramValues.Logs_Folder 			:= ProgramValues.Local_Folder "\Logs"
	ProgramValues.Others_Folder 		:= ProgramValues.Local_Folder "\Others"
;	updater link
	ProgramValues.Updater_File 			:= A_ScriptDir "\Game-Vivifier-Updater.exe"
	ProgramValues.Updater_Link 			:= "https://raw.githubusercontent.com/lemasato/Game-Vivifier/" ProgramValues.Branch "/Updater_v2.exe"
;	verion link / changelogs link
	ProgramValues.Version_Link 			:= "https://raw.githubusercontent.com/lemasato/Game-Vivifier/" ProgramValues.Branch "/version.txt"
	ProgramValues.Changelogs_Link 		:= "https://raw.githubusercontent.com/lemasato/Game-Vivifier/" ProgramValues.Branch "/changelogs.txt"
;	new version link
	ProgramValues.NewVersion_File		:= A_ScriptDir "\Game-Vivifier-NewVersion.exe"
	ProgramValues.NewVersion_Link 		:= "https://raw.githubusercontent.com/lemasato/Game-Vivifier/" ProgramValues.Branch "/Game Vivifier.exe"
;	local files
	ProgramValues.Ini_File 					:= ProgramValues.Local_Folder "\Preferences.ini"
	ProgramValues.Translations_File			:= ProgramValues.Local_Folder "\Translations.ini"
	ProgramValues.Changelogs_File 			:= ProgramValues.Logs_Folder "\Changelogs.txt"
	ProgramValues.Logs_File					:= ProgramValues.Logs_Folder "\DebugLogs.txt"	

;	special links
	ProgramValues.Link_GitHub				:= "https://github.com/lemasato/Game-Vivifier"
	ProgramValues.Link_AHK					:= "https://autohotkey.com/boards/viewtopic.php?t=9455"
	ProgramValues.Link_NVIDIA_Screenshot	:= "https://raw.githubusercontent.com/lemasato/Game-Vivifier/" ProgramValues.Branch "/Screenshots/Nvidia Control Panel.png"
	ProgramValues.Link_GitHub_Wiki 			:= "https://github.com/lemasato/Game-Vivifier/wiki"

	global ExcludedProcesses 			:= "explorer.exe,autohotkey.exe,nvcplui.exe," A_ScriptName

	ProgramValues.PID 					:= DllCall("GetCurrentProcessId")

	SetWorkingDir,% ProgramValues.Local_Folder
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;	Directories Creation
	directories := ProgramValues.Local_Folder
			. "`n" ProgramValues.Logs_Folder
			. "`n" ProgramValues.Others_Folder
	Loop, Parse, directories,% "`r`n"
	{
		if (!InStr(FileExist(A_LoopField), "D")) {
			FileCreateDir, % A_LoopField
		}
	}
; - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	Close_Previous_Program_Instance()

	Tray_Refresh()

	Update_Local_Settings()
	Set_Local_Settings()
	localSettings := Get_Local_Settings()
	Declare_Local_Settings(localSettings)
	Extract_Assets()

	Create_Tray_Menu()
	Update_Startup_Shortcut()

	gameProfilesSettings := Get_GameProfiles_Settings()
	Declare_GameProfiles_Settings(gameProfilesSettings)
	Enable_Hotkeys()

	Check_Update()
	NVCPL_Be_Ready()
	translations := Get_Translations("Tray_Notifications")
	Check_Conflicting_Applications()
	Tray_Notifications_Show(ProgramValues.Name " v" ProgramValues.Version, translations.MSG_Start), translations := ""
	Logs_Append("START", localSettings)

	SetTimer, Save_Temporary_GameProfiles, 600000
	; Gui_Settings()
	; Gui_About()
}

Set_ThisApp_Settings(winExe="", isHotkey=0) {
	global GameList, GameProfiles, ProgramSettings, NVIDIA_Values
	static previousMon

	; Get active win exe
	if (winExe = "") {
		WinGet, winExe, ProcessName, A
	}

	if !NVIDIA_Values.Is_Ready
		Return

	StartTime := A_TickCount

	currentMon := GetMonitorIndexFromWindow(), currentMon-- ; ; We must remove 1, as nvidia index starts at 0
	isFullScreen := Is_Window_FullScreen()

	; Set this executable settings
	if winExe in %GameList%
	{
		NVIDIA_Set_Settings(GameProfiles[winExe]["Gamma"], GameProfiles[winExe]["Vibrance"], currentMon, isFullScreen, isHotkey)
	}
	; Set default settings
	else {
		NVIDIA_Set_Settings(ProgramSettings.DEFAULT.Gamma, ProgramSettings.DEFAULT.Vibrance, currentMon, isFullScreen, isHotkey)
	}

	EndTime := A_TickCount

	previousMon := currentMon
}

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
 *																					*
 *			NVCPL FUNCTIONS															*
 *			Used to interact with the Nvidia Control Panel 							*
 *																					*
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
*/
	
NVCPL_Be_Ready() {
/*		Gets the NVCPL ready to receive our settings
*/
	global NVIDIA_Values

	NVIDIA_Values.Is_Ready := false

;	First retrieve the location
	NVCPL_Get_Location()
;	Then run, click on the Adjust Desktop setting and make sure it's the right control
	NVCPL_Run()
	NVCPL_Trigger_Control("Adjust_Desktop")
	NVCPL_Check_Control_Valid()
;	Finally run again
	NVCPL_Run()
	NVCPL_Trigger_Control("Adjust_Desktop")
	NVCPL_Trigger_Control("Select_Monitor", {Monitor:0,Force:1})
	NVCPL_Trigger_Control("Use_NVIDIA_Settings")
;	And hide the window
	WinHide,% "ahk_id " NVIDIA_Values.Handler
	; WinShow,% "ahk_id " NVIDIA_Values.Handler

	NVIDIA_Values.Is_Ready := true
}

NVCPL_Get_Location() {
/*		Retrieve the NVCPL location
 * 		If unable to find, ask the user to point it
*/
	global ProgramSettings, ProgramValues

	translations := Get_Translations("NVCPL_Get_Location")
	nvPath := ProgramSettings.NVIDIA_PANEL["Location"]

	SplitPath, nvPath, nvPath_fileName
	; Invalid path. Attempt to get its default location
	if ( nvPath = "ERROR" || nvPath = "" || !FileExist(nvPath) || nvPath_fileName != "nvcplui.exe" ) {
		EnvGet, _ProgramFiles, ProgramFiles
		EnvGet, _ProgramW6432, ProgramW6432
		EnvGet, _ProgramFiles_X86, ProgramFiles(x86)

		Path_ProgramFiles := _ProgramFiles "\NVIDIA Corporation\Control Panel Client\nvcplui.exe"
		Path_ProgramW6432 := _ProgramW6432 "\NVIDIA Corporation\Control Panel Client\nvcplui.exe"
		Path_ProgramFiles_X86 := _ProgramFiles_X86 "\NVIDIA Corporation\Control Panel Client\nvcplui.exe"

		if FileExist(Path_ProgramFiles)
			new_nvPath := Path_ProgramFiles
		else if FileExist(Path_ProgramW6432)
			new_nvPath := Path_ProgramW6432
		else if FileExist(Path_ProgramFiles_X86)
			new_nvPath := Path_ProgramFiles_X86
		else {
			MsgBox, 0x40030,% ProgramValues.Name,% translations.TXT_FiledToFind
			FileSelectFile, new_nvPath, 3, %progFiles%, Please go to \NVIDIA Corporation\Control Panel Client\nvcplui.exe, nvcplui.exe
			if ( ErrorLevel = 1 ) {
				%A_ThisFunc%()
			}
		}

		IniWrite,% """" new_nvPath """",% ProgramValues.Ini_File,NVIDIA_PANEL,Location
		ProgramSettings.NVIDIA_PANEL["Location"] := new_nvPath
		Sleep 100
		%A_ThisFunc%()
	}
}

NVCPL_Run() {
/*		Control IDs are generated dynamically as the user goes trough the NVCPL
 *		Therefore, we have to make sure the first tab clicked is the one we need
 *		So all the control names can be predicted
 */
 	global ProgramSettings, NVIDIA_Values, ProgramValues

 	detectHiddenWin := A_DetectHiddenWindows
 	DetectHiddenWindows, OFF

 	translations := Get_Translations(A_ThisFunc)

	nvPath 			:= ProgramSettings.NVIDIA_PANEL["Location"]
	staticCtrl 		:= ProgramSettings.NVIDIA_PANEL["Control_AdjustDesktop"]
	
	Process, Exist, nvcplui.exe
	existingPID := ErrorLevel

	Process, Close, %existingPID%
	Process, WaitClose, %existingPID%, 5
	if (ErrorLevel) {
		NVCPL_Run_CloseError:
		isAdmin := A_IsAdmin
		notAdminMsg := (isAdmin)?(""):("`n`n" translations.TEXT_NoAdmin)
		MsgBox, 4096,% ProgramValues.Name,% translations.TEXT_CloseFailed notAdminMsg
		Process, Exist, nvcplui.exe
		if (ErrorLevel) {
			Goto NVCPL_Run_CloseError
		}
	}

	; Run,% nvPath, , ,nvPID
	Run,% nvPath, , Min,nvPID
	WinWait,% "ahk_pid " nvPID,,20
	if (ErrorLevel) {
		NVCPL_Run_RunError:
		MsgBox, 4096,% ProgramValues.Name,% translations.TEXT_RunFailed
		WinWait,% "ahk_pid " nvPID,,5
		if (ErrorLevel) {
			Goto NVCPL_Run_RunError
		}
	}
	WinGet, nvHandler, ID,% "ahk_pid " nvPID
	DetectHiddenWindows, %detectHiddenWin%

	NVIDIA_Values.Handler 	:= nvHandler
	NVIDIA_Values.PID 		:= nvPID
}

NVCPL_Check_Control_Valid() {
/*		Verify the "Adjust Desktop" setting.
		If gamma/vibrance sliders are avaialble, high chances its valid.
		If not, ask the user to point the control again.
*/
	global NVIDIA_Values, ProgramValues, ProgramSettings

	nvHandler 						:= NVIDIA_Values.Handler
	adjustDesktopCtrl 				:= ProgramSettings.NVIDIA_PANEL.Control_AdjustDesktop
	adjustDesktopCtrl_Text 			:= ProgramSettings.NVIDIA_PANEL.Control_AdjustDesktopText
	
	; Show the NVCPL
	WinShow,% "ahk_id " nvHandler
	WinWait,% "ahk_id " nvHandler

	; Retrieve the control text
	if (adjustDesktopCtrl_Text) {
		Loop {
			ControlGetText, ctrlText,% adjustDesktopCtrl,% "ahk_id " nvHandler
			if (ctrlText || A_Index > 10)
				Break
			Sleep 500
		}
	}
	; Attempt to retrieve the control automatically
	if ( (adjustDesktopCtrl = "ERROR" || !adjustDesktopCtrl || adjustDesktopCtrl_Text = "ERROR" || !adjustDesktopCtrl_Text) || (ctrlText && ctrlText != adjustDesktopCtrl_Text)) {
		ctrlInfos := NVIDIA_Get_Control("Adjust Desktop")
		adjustDesktopCtrl := ctrlInfos[1], adjustDesktopCtrl_Text := ctrlInfos[2]
	}

	; Make sure the sliders gamma/vibrance are available on this tab
	Loop {
		if (A_Index > 10 ) { ; Too many attempts, try to get it automatically. If fail, the user will have to point it out
			NVIDIA_Get_Control("Adjust Desktop")
			%A_ThisFunc%()
		}
		if (323_clear && 324_clear) ; Both available, we good to go
			Break

		ControlClick,% adjustDesktopCtrl,% "ahk_id " nvHandler ; Click the control again, make sure we are on the tab

		if !(323_clear) { ; Try to reacch gamma slider
			PostMessage, 0x0405,0, ,msctls_trackbar323,% "ahk_id " nvHandler
			if (!ErrorLevel)
				323_clear := true
		}
		if !(324_clear) { ; Try to reach vibrance slider
			PostMessage, 0x0405,0, ,msctls_trackbar324,% "ahk_id " nvHandler
			if (!ErrorLevel)
				324_clear := true
		}
		Sleep 500
	}
}

NVIDIA_Get_Control(ctrlName) {
/*		Attempt to retrieve the control ID automatically
 *		Based on the control's text
*/
	global ProgramValues, NVIDIA_Values

	iniFilePath 		:= ProgramValues.Ini_File
	nvHandler 			:= NVIDIA_Values.Handler

	if (ctrlName = "Adjust Desktop") {
		i := 1, rtrn := "", handler := nvHandler
		validControls := "Régler les paramètres des couleurs du bureau" ; FR
					   . ",Adjust desktop color settings" ; EN

		Loop {
			ControlGetText, ctrlText,Static%i%, ahk_id %handler%
			if (!ctrlText && A_Index = 1) {
				While (!ctrlText) {
					ControlGetText, ctrlText,Static%i%, ahk_id %handler%
					Sleep 100
				}
			}
			if ctrlText in %validControls%
				found := true
			if (A_Index > 20 || found)
				Break
			i++
		}
		if (found) {
			ctrlStatic := "Static" i, ctrlStaticText := ctrlText
			IniWrite,Static%i%,% iniFilePath,NVIDIA_PANEL,Control_AdjustDesktop
			IniWrite,% ctrlStaticText,% iniFilePath,NVIDIA_PANEL,Control_AdjustDesktopText
		}
		else {
			ctrlInfos := Gui_GetControl("Adjust desktop color settings")
			ctrlStatic := ctrlInfos[1], ctrlStaticText := ctrlInfos[2]
			IniWrite,% ctrlStatic,% iniFilePath,NVIDIA_PANEL,Control_AdjustDesktop
			IniWrite,% ctrlStaticText,% iniFilePath,NVIDIA_PANEL,Control_AdjustDesktopText
		}
		return [ctrlStatic, ctrlStaticText]
	}
}

NVCPL_Trigger_Control(ctrlName, params="") {
/*		Click the "Use NVIDIA Settings" button
*/
	global NVIDIA_Values, ProgramSettings

	_nvHandler 				:= NVIDIA_Values.Handler
	_adjustDesktop 			:= ProgramSettings.NVIDIA_PANEL["Control_AdjustDesktop"]
	_useNVIDIASettings 		:= "Button4"
	_selectMonitor 			:= "SysListView321"
	_gammaSlider 			:= "msctls_trackbar323"

	_gammaMax := 280
	_gammaMin := 30

	if (ctrlName = "Use_NVIDIA_Settings") {
		ControlClick,% _useNVIDIASettings,% "ahk_id " _nvHandler ; Click it
		Sleep 100 ; Sleep to let the NVCPL process it
	}
	else if (ctrlName = "Adjust_Desktop") {
		ControlClick,% _adjustDesktop,% "ahk_id " _nvHandler ; Click it
		Sleep 100 ; Sleep, to let the NVCPL process it
	}
	else if (ctrlName = "Select_Monitor") {
		static prev_monitorID, isMonitorUsingNVIDIA := {} ; isMonitorUsingNVIDIA: If we clicked "Use NVIDIA Settings" for this monitor yet
		monitorID := params.Monitor
		prev_monitorID := (prev_monitorID = "")?(0):(prev_monitorID) ; No monitor previously selected. Default to 0

		monDiff := monitorID - prev_monitorID
		whichArrow := (monDiff > 0)?("Right"):("Left")

		if (whichArrow = "Left") {
			StringTrimLeft, monDiff, monDiff, 1 ; Remove the minus before the number
		}

		if (monDiff || params.Force) {
			if (!isMonitorUsingNVIDIA[monitorID])
				ControlClick,% _selectMonitor,% "ahk_id " _nvHandler
			if (params.Force) {
				SysGet, MonitorCount, MonitorCount
				monDiff 	:= MonitorCount, whichArrow := "Left"
				isForce 	:= "{Right " monitorID "}"
			}
			ControlSend,% _selectMonitor,{Blind}{%whichArrow% %monDiff%}%isForce%,% "ahk_id " _nvHandler ; Select monitor
			if (!isMonitorUsingNVIDIA[monitorID]) {
				NVCPL_Trigger_Control("Use_NVIDIA_Settings")
				isMonitorUsingNVIDIA[monitorID] := true
			}
		}

		prev_monitorID := monitorID
	}
	else if (ctrlName = "Gamma") {
		static prev_gamma
		gamma := params.Gamma, monitorID := params.Monitor

		whichArrow := (gamma > prevGamma)?("Right"):("Left")
		value := (whichArrow = "Right")?(gamma-2):(gamma+2)
		if (gamma >= _gammaMax)
			value := _gammaMax-2, whichArrow := "Right"
		else if (gamma <= gammaMin)
			value := _gammaMin+2, whichArrow := "Left"

		PostMessage, 0x0405,0,% value,% _gammaSlider,% "ahk_id " _nvHandler ; Send gamma
		ControlSend,% _gammaSlider, {Blind}{%whichArrow% 2},% "ahk_id " _nvHandler ; Move to update gamma slider

		prev_gamma := gamma
	}
	else if (ctrlName = "Vibrance") {
		vibrance := params.Vibrance, monitorID := params.Monitor
		NvApi.SetDVCLevelEx(vibrance, monitorID)
	}
	/*	These need to be fixed.
		A value of 80 means 0%. A value of 120 means 100%.
		Values last digit can only be 0 2 5 7.

	else if (ctrlName = "Brightness") {
		PostMessage, 0x0405,0,% meVal-1, msctls_trackbar321,% "ahk_exe nvcplui.exe" ; Send gamma
		ControlSend, msctls_trackbar321, {Blind}{Right},% "ahk_exe nvcplui.exe" ; Move to update gamma slider
	}
	else if (ctrlName = "Contrast") {
		PostMessage, 0x0405,0,% meVal-1, msctls_trackbar322,% "ahk_exe nvcplui.exe" ; Send gamma
		ControlSend, msctls_trackbar322, {Blind}{Space},% "ahk_exe nvcplui.exe" ; Move to update gamma slider
	}
	*/
}

NVIDIA_Set_Settings(gamma, vibrance, monitorID=0, isFullScreen=0, isHotkey=0) {
	global ProgramValues, NVIDIA_Values, ProgramSettings
	global NVIDIA_Set_Settings_FullScreen_CANCEL
	global NVIDIA_Set_Settings_FullScreen_START
	global NVIDIA_Set_Settings_FullScreen_HANDLE
	static prev_gamma, prev_vibrance, prev_MonitorID
	static _gamma, _vibrance, _monitorID, againIndex
	static winEXE, prev_winEXE

	hiddenWin := A_DetectHiddenWindows
	DetectHiddenWindows, On

	nvHandler := NVIDIA_Values.Handler

	if !(NVIDIA_Values.Is_Ready)
		Return

;	Check if NVCPL exsists
	if !( WinExist("ahk_id " nvHandler ) ) {
		translations := Get_Translations(A_ThisFunc)
		Tray_Notifications_Show(ProgramValues.Name, translations.TEXT_NvidiaNotFound)
		Sleep 5000
		NVCPL_Be_Ready()
		Return
	}

	WinGet, winEXE, ProcessName, A
	defaultGamma 		:= ProgramSettings.DEFAULT.Gamma
	defaultVibrance 	:= ProgramSettings.DEFAULT.Vibrance

	if (gamma="prev") {
		gamma := (IsNum(prev_gamma))?(prev_gamma):(defaultGamma)
	}
	if (vibrance="prev") {
		vibrance := (IsNum(prev_vibrance))?(prev_vibrance):(defaultVibrance)
	}

	isGammaDiff		 := (gamma != prev_gamma)?(true):(false)
	isVibranceDiff	 := (vibrance != prev_vibrance)?(true):(false)
	isAppDiff 		 := (winExe != prev_winEXE)?(true):(false)
	idMonDiff 		 := (monitorID != prev_monitorID)?(true):(false)

	wasPrevGammaNotDef 		:= (prev_gamma != defaultGamma)?(true):(false)
	wasPrevVibranceNotDef 	:= (prev_vibrance != defaultVibrance)?(true):(false)

	isCurrentGammaNotDef 		:= (gamma != defaultGamma)?(true):(false)
	isCurrentVibranceNotDef 	:= (vibrance != defaultVibrance)?(true):(false)

	; Reset previous monitor settings
	if (idMonDiff) {
		
		if ( wasPrevGammaNotDef && IsNum(defaultGamma)  ) 
			NVCPL_Trigger_Control("Gamma", {Gamma:defaultGamma, Monitor:prev_MonitorID})
		if ( wasPrevVibranceNotDef && IsNum(defaultVibrance)  )
			NVCPL_Trigger_Control("Vibrance", {Vibrance:defaultVibrance, Monitor:prev_MonitorID})
	}
	if ( isGammaDiff || isVibranceDiff || isHotkey || (!isAppDiff && (isCurrentGammaNotDef || isCurrentVibranceNotDef)) ) {
		NVCPL_Trigger_Control("Select_Monitor", {Monitor:monitorID})
		if ( isGammaDiff && IsNum(gamma) || isHotkey || idMonDiff || (!isAppDiff && isCurrentGammaNotDef) ) {
			NVCPL_Trigger_Control("Gamma", {Gamma:gamma, Monitor:monitorID})
		}
		if ( isVibranceDiff && IsNum(vibrance) || isHotkey || idMonDiff || (!isAppDiff && isCurrentVibranceNotDef) )
			NVCPL_Trigger_Control("Vibrance", {Vibrance:vibrance, Monitor:monitorID})

		; Fullscreen app tend to revert our settings, we wait a bit then re-apply them
		if ( isFullScreen ) {
			NVIDIA_Set_Settings_FullScreen_HANDLE := WinActive("A")
			NVIDIA_Set_Settings_FullScreen_START := true
			_gamma := gamma, _vibrance := vibrance, _monitorID := monitorID, againIndex := 0
			SetTimer, %A_ThisFunc%_FullScreen, -2000
		}
	}

	prev_gamma := gamma, prev_vibrance := vibrance, prev_MonitorID := monitorID, prev_winEXE := winEXE
	DetectHiddenWindows, %hiddenWin%
	Return

	NVIDIA_Set_Settings_FullScreen:
		if (NVIDIA_Set_Settings_FullScreen_CANCEL ) {
			NVIDIA_Set_Settings_FullScreen_CANCEL := false
			NVIDIA_Set_Settings_FullScreen_START := false
			againIndex := 0
		}
		else if (againIndex <= 3) {
			NVCPL_Trigger_Control("Gamma", {Gamma:_gamma, Monitor:_monitorID})
			NVCPL_Trigger_Control("Vibrance", {Vibrance:_vibrance, Monitor:_monitorID})
			SetTimer, %A_ThisLabel%, -2000
		}
		else {
			NVIDIA_Set_Settings_FullScreen_START := false
			againIndex := 0
		}
	Return
}

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
 *			SETTINGS GUI															*
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
*/

Gui_Settings() {
	global ProgramSettings, ProgramValues, GameProfiles
	global GUISettings_Controls := {}
	global GuiSettings_Submit := {}

	translations := Get_Translations(A_ThisFunc)
	labelPrefix := "Gui_Settings_"
	profileBoxWidth := 250, profileBoxHeight := 300
	detectHiddenWin := false

	Gui, Settings:Destroy
	Gui, Settings:New, +AlwaysOnTop +SysMenu -MinimizeBox -MaximizeBox +OwnDialogs +Label%labelPrefix% +Delimiter`n hwndhGuiSettings,% "Settings"

;	GENERAL SETTINGS
	Gui_Add({_Name:"Settings",_Font:"Segoe UI",_Type:"GroupBox",_Content:translations.GB_GeneralSettings,_Pos:"xm+5 w" (profileBoxWidth*2)+80 " h70",_Color:"Black",_Opts:"Section"})
	Gui_Add({_Type:"DropDownList",_Content:translations.DDL_Language,_Pos:"xp+10 yp+20",_Var:"DDL_Language",_Label:labelPrefix "OnLanguageChange"})
	Gui_Control("Settings", "ChooseString" ,GuiSettings_Controls.DDL_Language, ProgramSettings.SETTINGS.Language) ; Choose language __TO_BE_CHANGED__ Add something in Gui_Add that use Gui_Control() when using the ChooseString parameter
	Gui_Add({_Type:"Checkbox",_Content:translations.CB_RunOnStartup,_Var:"CB_RunOnStartup",_Label:labelPrefix "OnDefaultSettingsChange",_CB_State:ProgramSettings.SETTINGS.RunOnStartup})
	; Gamma default
	Gui_Add({_Type:"Text",_Content:translations.TEXT_DefaultGamma,_Pos:"xs+350 ys+15"})
	Gui_Add({_Type:"Edit",_Content:"",_Pos:"xp+20 y+5 w50",_Opts:"ReadOnly"})
	Gui_Add({_Type:"UpDown",_Content:ProgramSettings.DEFAULT.Gamma,_Var:"EDIT_DefaultGamma",_Label:labelPrefix "OnDefaultSettingsChange",_Opts:"Range30-280"})
	; Vibrance default
	Gui_Add({_Type:"Text",_Content:translations.TEXT_DefaultVibrance,_Pos:"xs+450 ys+15"})
	Gui_Add({_Type:"Edit",_Content:"",_Pos:"xp+20 y+5 w50",_Opts:"ReadOnly"})
	Gui_Add({_Type:"UpDown",_Content:ProgramSettings.DEFAULT.Vibrance,_Var:"EDIT_DefaultVibrance",_Label:labelPrefix "OnDefaultSettingsChange",_Opts:"Range0-100"})
	; Monitor ID
/*	Disabled, as the monitor ID is automatically retrieved based on window position
	Gui_Add({_Type:"Text",_Content:translations.TEXT_MonitorID,_Pos:"xs+420 ys+15"})
	Gui_Add({_Type:"Edit",_Content:"",_Pos:"xp+5 y+5 w50",_Opts:"ReadOnly"})
	Gui_Add({_Type:"UpDown",_Content:ProgramSettings.Monitor_ID,_Var:"EDIT_MonitorID",_Label:labelPrefix "OnDefaultSettingsChange",_Opts:"Range0-100"})
*/

;	RUNNING APPLICATIONS
	Gui_Add({_Type:"GroupBox",_Content:translations.GB_RunningApplications,_Pos:"xm+5 w" profileBoxWidth-8 " h30",_Color:"Black"})
	Gui_Add({_Type:"ListBox",_Content:"",_Pos:"xm yp+20 w" profileBoxWidth " h" profileBoxHeight,_Label:labelPrefix "LB_RunningApplications_OnSelect",_Var:"LB_RunningApps"})

;	MIDDLE BUTTONS
	Gui_Add({_Type:"Button",_Content:translations.BTN_ToggleHidden,_Pos:"xp+" profileBoxWidth " yp-1 w80 h40",_Label:labelPrefix "ToggleHidden",_Opts:"Section"})
	Gui_Add({_Type:"Button",_Content:translations.BTN_AddSelectedWindow,_Pos:"xp ys+" (profileBoxHeight/2)-66 " hp wp",_Label:labelPrefix "AddSelectedWindow"})
	Gui_Add({_Type:"Button",_Content:translations.BTN_RefreshWindows,_Pos:"xp yp+40 hp wp",_Label:labelPrefix "RefreshWindows"})
	Gui_Add({_Type:"Button",_Content:translations.BTN_RemoveSelectedWindow,_Pos:"xp yp+40 hp wp",_Label:labelPrefix "RemoveSelectedWindow"})
	Gui_Add({_Type:"Button",_Content:translations.BTN_ShowHelp,_Pos:"xp ys+" (profileBoxHeight)-48 " hp wp",_Label:labelPrefix "Help"})

;	MY SETTINGS
	Gui_Add({_Type:"GroupBox",_Content:translations.GB_MySettings,_Pos:"xs+85 ys-20 w" profileBoxWidth-8 " h30",_Color:"Black"})
	Gui_Add({_Type:"ListBox",_Content:"",_Pos:"xs+80 yp+20 w" profileBoxWidth " h" profileBoxHeight,_Var:"LB_MySettings",_Label:labelPrefix "LB_MySettings_OnSelect"})

;	SELECTED APP SETTINGS
	Gui_Add({_Type:"GroupBox",_Content:translations.GB_SelectedAppSettings,_Pos:"xm w" (profileBoxWidth*2)+80 " h80",_Color:"Black",_Opts:"Section"})
	; Gamma
	Gui_Add({_Type:"Text",_Content:translations.TEXT_Gamma,_Pos:"xs+80 ys+25"})
	Gui_Add({_Type:"Edit",_Pos:"x+10 yp-3 w50",_Opts:"ReadOnly"})
	Gui_Add({_Type:"UpDown",_Content:ProgramSettings.DEFAULT.Gamma,_Var:"EDIT_SelectedAppGamma",_Label:labelPrefix "SelectedAppSettings_OnGammaChange",_Opts:"Disabled Range30-280"})
	Gui_Add({_Type:"Slider",_Content:ProgramSettings.DEFAULT.Gamma,_Pos:"xp-100 y+0 w210",_Var:"SLIDER_SelectedAppGamma",_Label:labelPrefix "SelectedAppSettings_OnGammaChange",_Opts:"Disabled AltSubmit Line5 Page5 ToolTip Range30-280"})
	; Vibrance
	Gui_Add({_Type:"Text",_Content:translations.TEXT_Vibrance,_Pos:"xs+360 ys+25"})
	Gui_Add({_Type:"Edit",_Pos:"x+10 yp-3 w50",_Opts:"ReadOnly"})
	Gui_Add({_Type:"UpDown",_Content:ProgramSettings.DEFAULT.Vibrance,_Var:"EDIT_SelectedAppVibrance",_Label:labelPrefix "SelectedAppSettings_OnVibranceChange",_Opts:"Disabled Range0-100"})
	Gui_Add({_Type:"Slider",_Content:ProgramSettings.DEFAULT.Vibrance,_Pos:"xp-100 y+0 w210",_Var:"SLIDER_SelectedAppVibrance",_Label:labelPrefix "SelectedAppSettings_OnVibranceChange",_Opts:"Disabled AltSubmit Line5 Page5 ToolTip Range0-100"})

;	HOTKEYS
	hkSettings := ProgramSettings.HOTKEYS
	hkModSettings := ProgramSettings.HOTKEYS_MODIFIERS

	Gui_Add({_Type:"GroupBox",_Content:translations.GB_Hotkeys,_Pos:"xm y+10 w" (profileBoxWidth*2)+80 " h120",_Color:"Black",_Opts:"Section"})
	Gui_Add({_Type:"ListBox",_Content:"Gamma`nVibrance`nSpecial",_Pos:"xs+10 ys+20 w120 R3",_Var:"LB_Hotkeys",_Label:labelPrefix "LB_OnHotkeyTabSelect",_Choose:"1",_Opts:"Section"})
	Gui_Add({_Type:"Tab2",_Pos:"x0 y0 w0 h0",_Content:"Gamma`nVibrance`nSpecial",_Var:"TAB_Hotkeys",_Opts:"-Wrap"})
	; GAMMA
	; Gamma++
	Gui, Settings:Tab, Gamma
	Gui_Add({_Type:"Text",_Content:translations.TEXT_Increase,_Pos:"xs+140 ys+5"})
	Gui_Add({_Type:"Hotkey",_Content:hkSettings["GammaPlus"],_Pos:"x+5 yp-3 w125",_Var:"HK_GammaPlus",_Label:labelPrefix "HK_OnHotkeyChange",_Opts:"Limit190"}) ; 190 = no modifier allowed - modifier are replaced by !^
	Gui_Add({_Type:"Checkbox",_Content:"CTRL",_Pos:"xs+140 y+5",_Label:labelPrefix "CB_OnHotkeyCheckModifier",_Var:"CB_GammaPlusCTRL",_CB_State:hkModSettings["GammaPlusCTRL"]})
	Gui_Add({_Type:"Checkbox",_Content:"ALT",_Pos:"x+0 yp",_Label:labelPrefix "CB_OnHotkeyCheckModifier",_Var:"CB_GammaPlusALT",_CB_State:hkModSettings["GammaPlusALT"]})
	Gui_Add({_Type:"Checkbox",_Content:"SHIFT",_Pos:"x+0 yp",_Label:labelPrefix "CB_OnHotkeyCheckModifier",_Var:"CB_GammaPlusSHIFT",_CB_State:hkModSettings["GammaPlusSHIFT"]})
	Gui_Add({_Type:"Checkbox",_Content:"WIN",_Pos:"x+0 yp",_Label:labelPrefix "CB_OnHotkeyCheckModifier",_Var:"CB_GammaPlusWIN",_CB_State:hkModSettings["GammaPlusWIN"]})
	; Gamma --
	Gui_Add({_Type:"Text",_Content:translations.TEXT_Reduce,_Pos:"xs+360 ys+5"})
	Gui_Add({_Type:"Hotkey",_Content:hkSettings["GammaMinus"],_Pos:"x+5 yp-3 w125",_Var:"HK_GammaMinus",_Label:labelPrefix "HK_OnHotkeyChange",_Opts:"Limit190"}) ; 190 = no modifier allowed - modifier are replaced by !^
	Gui_Add({_Type:"Checkbox",_Content:"CTRL",_Pos:"xs+360 y+5",_Label:labelPrefix "CB_OnHotkeyCheckModifier",_Var:"CB_GammaMinusCTRL",_CB_State:hkModSettings["GammaMinusCTRL"]})
	Gui_Add({_Type:"Checkbox",_Content:"ALT",_Pos:"x+0 yp",_Label:labelPrefix "CB_OnHotkeyCheckModifier",_Var:"CB_GammaMinusALT",_CB_State:hkModSettings["GammaMinusALT"]})
	Gui_Add({_Type:"Checkbox",_Content:"SHIFT",_Pos:"x+0 yp",_Label:labelPrefix "CB_OnHotkeyCheckModifier",_Var:"CB_GammaMinusSHIFT",_CB_State:hkModSettings["GammaMinusSHIFT"]})
	Gui_Add({_Type:"Checkbox",_Content:"WIN",_Pos:"x+0 yp",_Label:labelPrefix "CB_OnHotkeyCheckModifier",_Var:"CB_GammaMinusWIN",_CB_State:hkModSettings["GammaMinusWIN"]})

	Gui_Add({_Type:"Text",_Pos:"xs ys+50",_Content:translations.TEXT_HK_GammaTabHelp})
	; VIBRANCE
	; Vibrance ++
	Gui, Settings:Tab, Vibrance
	Gui_Add({_Type:"Text",_Content:translations.TEXT_Increase,_Pos:"xs+140 ys+5"})
	Gui_Add({_Type:"Hotkey",_Content:hkSettings["VibrancePlus"],_Pos:"x+5 yp-3 w125",_Var:"HK_VibrancePlus",_Label:labelPrefix "HK_OnHotkeyChange",_Opts:"Limit190"}) ; 190 = no modifier allowed - modifier are replaced by !^
	Gui_Add({_Type:"Checkbox",_Content:"CTRL",_Pos:"xs+140 y+5",_Label:labelPrefix "CB_OnHotkeyCheckModifier",_Var:"CB_VibrancePlusCTRL",_CB_State:hkModSettings["VibrancePlusCTRL"]})
	Gui_Add({_Type:"Checkbox",_Content:"ALT",_Pos:"x+0 yp",_Label:labelPrefix "CB_OnHotkeyCheckModifier",_Var:"CB_VibrancePlusALT",_CB_State:hkModSettings["VibrancePlusALT"]})
	Gui_Add({_Type:"Checkbox",_Content:"SHIFT",_Pos:"x+0 yp",_Label:labelPrefix "CB_OnHotkeyCheckModifier",_Var:"CB_VibrancePlusSHIFT",_CB_State:hkModSettings["VibrancePlusSHIFT"]})
	Gui_Add({_Type:"Checkbox",_Content:"WIN",_Pos:"x+0 yp",_Label:labelPrefix "CB_OnHotkeyCheckModifier",_Var:"CB_VibrancePlusWIN",_CB_State:hkModSettings["VibrancePlusWIN"]})
	; Vibrance --
	Gui_Add({_Type:"Text",_Content:translations.TEXT_Reduce,_Pos:"xs+360 ys+5"})
	Gui_Add({_Type:"Hotkey",_Content:hkSettings["VibranceMinus"],_Pos:"x+5 yp-3 w125",_Var:"HK_VibranceMinus",_Label:labelPrefix "HK_OnHotkeyChange",_Opts:"Limit190"}) ; 190 = no modifier allowed - modifier are replaced by !^
	Gui_Add({_Type:"Checkbox",_Content:"CTRL",_Pos:"xs+360 y+5",_Label:labelPrefix "CB_OnHotkeyCheckModifier",_Var:"CB_VibranceMinusCTRL",_CB_State:hkModSettings["VibranceMinusCTRL"]})
	Gui_Add({_Type:"Checkbox",_Content:"ALT",_Pos:"x+0 yp",_Label:labelPrefix "CB_OnHotkeyCheckModifier",_Var:"CB_VibranceMinusALT",_CB_State:hkModSettings["VibranceMinusALT"]})
	Gui_Add({_Type:"Checkbox",_Content:"SHIFT",_Pos:"x+0 yp",_Label:labelPrefix "CB_OnHotkeyCheckModifier",_Var:"CB_VibranceMinusSHIFT",_CB_State:hkModSettings["VibranceMinusSHIFT"]})
	Gui_Add({_Type:"Checkbox",_Content:"WIN",_Pos:"x+0 yp",_Label:labelPrefix "CB_OnHotkeyCheckModifier",_Var:"CB_VibranceMinusWIN",_CB_State:hkModSettings["VibranceMinusWIN"]})

	Gui_Add({_Type:"Text",_Pos:"xs ys+50",_Content:translations.TEXT_HK_VibranceTabHelp})
	; SPECIAL
	; Trigger settings
	Gui, Settings:Tab, Special
	Gui_Add({_Type:"Text",_Content:translations.TEXT_TriggerSave,_Pos:"xs+140 ys+5"})
	Gui_Add({_Type:"Hotkey",_Content:hkSettings["TriggerAndSave"],_Pos:"x+5 yp-3 w125",_Var:"HK_TriggerAndSave",_Label:labelPrefix "HK_OnHotkeyChange",_Opts:"Limit190"}) ; 190 = no modifier allowed - modifier are replaced by !^
	Gui_Add({_Type:"Checkbox",_Content:"CTRL",_Pos:"xs+140 y+5",_Label:labelPrefix "CB_OnHotkeyCheckModifier",_Var:"CB_TriggerAndSaveCTRL",_CB_State:hkModSettings["TriggerAndSaveCTRL"]})
	Gui_Add({_Type:"Checkbox",_Content:"ALT",_Pos:"x+0 yp",_Label:labelPrefix "CB_OnHotkeyCheckModifier",_Var:"CB_TriggerAndSaveALT",_CB_State:hkModSettings["TriggerAndSaveALT"]})
	Gui_Add({_Type:"Checkbox",_Content:"SHIFT",_Pos:"x+0 yp",_Label:labelPrefix "CB_OnHotkeyCheckModifier",_Var:"CB_TriggerAndSaveSHIFT",_CB_State:hkModSettings["TriggerAndSaveSHIFT"]})
	Gui_Add({_Type:"Checkbox",_Content:"WIN",_Pos:"x+0 yp",_Label:labelPrefix "CB_OnHotkeyCheckModifier",_Var:"CB_TriggerAndSaveWIN",_CB_State:hkModSettings["TriggerAndSaveWIN"]})
	; Save settings
	; Gui_Add({_Type:"Text",_Content:"Save:",_Pos:"xs+360 ys+5"})
	; Gui_Add({_Type:"Hotkey",_Content:"",_Pos:"x+5 yp-3 w125",_Var:"HK_SaveSettings",_Label:"",_Opts:"Limit190"}) ; 190 = no modifier allowed - modifier are replaced by !^
	; Gui_Add({_Type:"Checkbox",_Content:"CTRL",_Pos:"xs+360 y+5",_Var:"CB_SaveSettingsCTRL"})
	; Gui_Add({_Type:"Checkbox",_Content:"ALT",_Pos:"x+0 yp",_Var:"CB_SaveSettingsALT"})
	; Gui_Add({_Type:"Checkbox",_Content:"SHIFT",_Pos:"x+0 yp",_Var:"CB_SaveSettingsSHIFT"})
	; Gui_Add({_Type:"Checkbox",_Content:"WIN",_Pos:"x+0 yp",_Var:"CB_SaveSettingsWIN"})

	Gui_Add({_Type:"Text",_Pos:"xs ys+50",_Content:translations.TEXT_HK_SpecialTabHelp})

	; Gui_Control("Settings", "ChooseString", GuiSettings_Controls["TAB_Hotkeys"], "Gamma")
	GoSub Gui_Settings_RefreshWindows
	GoSub Gui_Settings_RefreshSettings
	Gui, Settings:Show
	Return

	Gui_Settings_LB_OnHotkeyTabSelect:
		GoSub Gui_Settings_Submit

		clickedTab := GuiSettings_Submit["LB_Hotkeys"]
		Gui_Control("Settings", "ChooseString", GuiSettings_Controls["TAB_Hotkeys"],clickedTab)
	Return

	Gui_Settings_CB_OnHotkeyCheckModifier:
		GoSub Gui_Settings_Submit

		isChecked := GuiSettings_Submit[A_GuiControl]
		StringTrimLeft, iniKey, A_GuiControl, 3
		IniWrite,% isChecked,% ProgramValues.Ini_File,% "HOTKEYS",% iniKey
	Return

	Gui_Settings_HK_OnHotkeyChange:
		GoSub Gui_Settings_Submit
		isHotkeyReplaced := false

		; Replace the ^! string, which replace any modifier by default when using Limit190
		thisHotkey := StrReplace(GuiSettings_Submit[A_GuiControl], "^!", "", replaceCount) ; remove default modifier
		firstChar := SubStr(thisHotkey, 1, 1)

		; Remove the first character if its a modifier, since even with Limit190 some keys such as mod+numpad button can pass through
		if (firstChar = "!" || firstChar = "^" || firstChar = "+") {
			StringTrimLeft, thisHotkey, thisHotkey, 1
			isHotkeyReplaced := true
		}

		; Replace the current content with the new replaced one
		if (replaceCount || isHotkeyReplaced) {
			Gui_Control("Settings", ,GuiSettings_Controls[A_GuiControl], thisHotkey)
		}
		
		StringTrimLeft, iniKey, A_GuiControl, 3
		IniWrite,% thisHotkey,% ProgramValues.Ini_File,% "HOTKEYS",% iniKey
	Return

	Gui_Settings_LB_RunningApplications_OnSelect:
	/*		Disable the "Selected application settings" sliders upon selecting from the "Running Applications" LB.
	*/
		Gui_Control("Settings", "Choose",GuiSettings_Controls.LB_MySettings, "0") ; So we can only have one list selected at a time

		Gui_Control("Settings", "+Disabled",GuiSettings_Controls.EDIT_SelectedAppGamma) ; Set +Disabled state
		Gui_Control("Settings", "+Disabled",GuiSettings_Controls.SLIDER_SelectedAppGamma)
		Gui_Control("Settings", "+Disabled",GuiSettings_Controls.EDIT_SelectedAppVibrance)
		Gui_Control("Settings", "+Disabled",GuiSettings_Controls.SLIDER_SelectedAppVibrance)
	Return


	Gui_Settings_OnDefaultSettingsChange:
	/*		Triggered upon changing value for default gamma/vibrance or monitor ID
	*/
		GoSub, Gui_Settings_Submit
	Return

	Gui_Settings_OnLanguageChange:
		GoSub, Gui_Settings_Submit

		RegExMatch(GuiSettings_Submit.DDL_Language, "(.*)-", lang)
		StringTrimRight, lang, lang, 1
		ProgramSettings.SETTINGS.Language := lang
		if (lang) {
			IniWrite,% lang,% ProgramValues.Ini_File,SETTINGS, Language
			Gui_Settings()
		}
	Return

	Gui_Settings_SelectedAppSettings_OnGammaChange:
		GoSub, Gui_Settings_Submit

		; No settting selected, abort
		if !(selectedSetting)
			Return

		; Once we are done moving sliders
		if (A_GuiEvent = "Normal" || A_GuiEvent = 4) { ; 4 = mouse wheel.
			; We are moving SLIDER, adjust EDIT
			if A_GuiControl contains SLIDER
			{
				Gui_Control("Settings", ,GuiSettings_Controls.EDIT_SelectedAppGamma, GuiSettings_Submit.SLIDER_SelectedAppGamma)
			}
			; We changed EDIT, adjust SLIDER
			else if A_GuiControl contains EDIT
			{
				Gui_Control("Settings", ,GuiSettings_Controls.SLIDER_SelectedAppGamma, GuiSettings_Submit.EDIT_SelectedAppGamma)
			}
			
			Gosub, Gui_Settings_Submit
			IniWrite,% GuiSettings_Submit.SLIDER_SelectedAppGamma,% ProgramValues.Ini_File,% selectedSetting,Gamma ; Write ini setting for this executable
			GameProfiles[selectedSetting]["Gamma"] 		:= GuiSettings_Submit.SLIDER_SelectedAppGamma ; Set the new setting, for fast preview
		}
	Return

	Gui_Settings_SelectedAppSettings_OnVibranceChange:
		GoSub, Gui_Settings_Submit

		if !(selectedSetting)
			Return

		if (A_GuiEvent = "Normal" || A_GuiEvent = 4) {
			if A_GuiControl contains SLIDER
			{
				Gui_Control("Settings", ,GuiSettings_Controls.EDIT_SelectedAppVibrance, GuiSettings_Submit.SLIDER_SelectedAppVibrance)
			}
			else if A_GuiControl contains EDIT
			{
				Gui_Control("Settings", ,GuiSettings_Controls.SLIDER_SelectedAppVibrance, GuiSettings_Submit.EDIT_SelectedAppVibrance)
			}
			Gosub, Gui_Settings_Submit
			IniWrite,% GuiSettings_Submit.SLIDER_SelectedAppVibrance,% ProgramValues.Ini_File,% selectedSetting,Vibrance
			GameProfiles[selectedSetting]["Vibrance"] 	:= GuiSettings_Submit.SLIDER_SelectedAppVibrance
		}
	Return

	Gui_Settings_GetMySettings:
		IniRead, allSections,% ProgramValues.Ini_File

		mySettings := ""
		Loop, Parse, allSections,% "`n`r"
		{
			if RegExMatch(A_LoopField, ".exe") {
				mySettings .= A_LoopField "`n"
			}
		}

		Sort, mySettings
	Return

	Gui_Settings_LB_MySettings_OnSelect:
	/*		Triggered when clicking on an item from the "My Settings" listbox
	*/
		Gosub Gui_Settings_Submit

		selectedSetting := GuiSettings_Submit.LB_MySettings
		if !(selectedSetting)
			Return

		; Get the settings
		IniRead, this_gamma,% ProgramValues.Ini_File,% selectedSetting,Gamma,% ProgramSettings.DEFAULT.Gamma
		IniRead, this_vibrance,% ProgramValues.Ini_File,% selectedSetting,Vibrance,% ProgramSettings.DEFAULT.Gamma
		; Gamma
		Gui_Control("Settings", ,GuiSettings_Controls.EDIT_SelectedAppGamma, this_gamma)
		Gui_Control("Settings", ,GuiSettings_Controls.SLIDER_SelectedAppGamma, this_gamma)
		; Vibrance
		Gui_Control("Settings", ,GuiSettings_Controls.EDIT_SelectedAppVibrance, this_vibrance)
		Gui_Control("Settings", ,GuiSettings_Controls.SLIDER_SelectedAppVibrance, this_vibrance)
		; Enable the controls
		Gui_Control("Settings", "-Disabled",GuiSettings_Controls.EDIT_SelectedAppGamma)
		Gui_Control("Settings", "-Disabled",GuiSettings_Controls.SLIDER_SelectedAppGamma)
		Gui_Control("Settings", "-Disabled",GuiSettings_Controls.EDIT_SelectedAppVibrance)
		Gui_Control("Settings", "-Disabled",GuiSettings_Controls.SLIDER_SelectedAppVibrance)
		; Un-select left list item
		Gui_Control("Settings", "Choose",GuiSettings_Controls.LB_RunningApps, "0")
	Return

	Gui_Settings_ToggleHidden:
/*		Toggle on/off hidden windows detection
*/
		detectHiddenWin := !detectHiddenWin
		GoSub Gui_Settings_RefreshWindows
	Return

	Gui_Settings_AddSelectedWindow:
/*		Add the selected window to "My Settings"
*/
		GoSub, Gui_Settings_Submit

		RegExMatch(GuiSettings_Submit.LB_RunningApps, "(.*?).exe", selectedItem)
		if (selectedItem) {
			IniWrite,% ProgramSettings.DEFAULT.Gamma,% ProgramValues.Ini_File,% selectedItem,Gamma
			IniWrite,% ProgramSettings.DEFAULT.Vibrance,% ProgramValues.Ini_File,% selectedItem,Vibrance
			gameProfilesSettings := Get_GameProfiles_Settings()
			Declare_GameProfiles_Settings(gameProfilesSettings)

			GoSub Gui_Settings_RefreshWindows
			GoSub Gui_Settings_RefreshSettings
		}
	Return

	Gui_Settings_RemoveSelectedWindow:
/*		Remove the selected window from "My Settings"
*/	
		GoSub, Gui_Settings_Submit

		RegExMatch(GuiSettings_Submit.LB_MySettings, "(.*?).exe", selectedItem)
		if (selectedItem) {
			; Remove this executable from file
			IniDelete,% ProgramValues.Ini_File,% selectedItem
			gameProfilesSettings := Get_GameProfiles_Settings()
			Declare_GameProfiles_Settings(gameProfilesSettings)

			; Disable the sliders
			Gui_Control("Settings", "+Disabled",GuiSettings_Controls.EDIT_SelectedAppGamma)
			Gui_Control("Settings", "+Disabled",GuiSettings_Controls.SLIDER_SelectedAppGamma)
			Gui_Control("Settings", "+Disabled",GuiSettings_Controls.EDIT_SelectedAppVibrance)
			Gui_Control("Settings", "+Disabled",GuiSettings_Controls.SLIDER_SelectedAppVibrance)

			; Refrsh both LB
			GoSub Gui_Settings_RefreshSettings
			GoSub Gui_Settings_RefreshWindows
		}
	Return

	Gui_Settings_RefreshWindows:
/*		Refresh the "Running applications"
*/
		Gui_Submit(GuiSettings_Controls,"Settings","NoHide")

		GoSub, Gui_Settings_GetMySettings
		runningApps := Get_Running_Apps(detectHiddenWin, mySettings, "`n")

		Gui_Control("Settings", ,GuiSettings_Controls.LB_RunningApps, "`n" runningApps)
	Return

	Gui_Settings_RefreshSettings:
/*		Refresh "My Settings"
*/
		GoSub, Gui_Settings_GetMySettings

		Gui_Control("Settings", ,GuiSettings_Controls.LB_MySettings, "`n" mySettings)
	Return

	Gui_Settings_Help:
/*		Show the help tooltip
*/
		Run,% ProgramValues.Link_GitHub_Wiki "/Usage"
	Return

	Gui_Settings_Submit:
/*		Retrieve all controls values into an array
		Also set the new default gamma/vibrance values
*/
		Gui_Submit(GUISettings_Controls, "Settings", "NoHide")

		ProgramSettings.DEFAULT.Gamma 			:= GuiSettings_Submit.EDIT_DefaultGamma
		ProgramSettings.DEFAULT.Vibrance 		:= GuiSettings_Submit.EDIT_DefaultVibrance
		; ProgramSettings.SETTINGS.Monitor_ID		:= GuiSettings_Submit.EDIT_MonitorID
		ProgramSettings.SETTINGS.RunOnStartup 	:= GuiSettings_Submit.CB_RunOnStartup
	Return

	Gui_Settings_SaveSettings:
/*		Save the settings into the local file
		Executable-specific settings do not need to be saved here,
			as they are automatically saved upon releasing the slider
*/
		; IniWrite,% GuiSettings_Submit.EDIT_MonitorID,% ProgramValues.Ini_File,SETTINGS,Monitor_ID
		IniWrite,% GuiSettings_Submit.CB_RunOnStartup,% ProgramValues.Ini_File,SETTINGS,RunOnStartup

		IniWrite,% GuiSettings_Submit.EDIT_DefaultGamma,% ProgramValues.Ini_File,DEFAULT,Gamma
		IniWrite,% GuiSettings_Submit.EDIT_DefaultVibrance,% ProgramValues.Ini_File,DEFAULT,Vibrance

		Update_Startup_Shortcut()
	Return

	Gui_Settings_Close:
/*		Close the GUI, saving all settings
*/		GoSub Gui_Settings_Submit
		GoSub Gui_Settings_SaveSettings

		Disable_Hotkeys()

		localSettings := Get_Local_Settings()
		Declare_Local_Settings(localSettings)

		gameProfilesSettings := Get_GameProfiles_Settings()
		Declare_GameProfiles_Settings(gameProfilesSettings)

		Enable_Hotkeys()
		Create_Tray_Menu()

		Gui, Settings:Destroy
	Return
}

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
 *					ABOUT GUI 														*
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
*/

Gui_About(params="") {
	static
	global ProgramValues, ProgramSettings
	global GuiAbout_Controls := {}
	global GuiAbout_Submit := {}

	Check_Update()

	iniFilePath := ProgramValues.Ini_File, programName := ProgramValues.Name
	verCurrent := ProgramValues.Version, verLatest := ProgramValues.Version_Latest
	isUpdateAvailable := ProgramValues.Update_Available, onlineVersionAvailable := ProgramValues.Version_Online
	paypalPicture := ProgramValues.Others_Folder "\DonatePaypal.png"

	IniRead, isAutoUpdateEnabled,% iniFilePath,PROGRAM,Auto_Update

;	Parse changelogs
	FileRead, changelogText,% ProgramValues.Changelogs_File
	allChanges := Object()
	allVersions := ""
	Loop {
		if RegExMatch(changelogText, "sm)\\\\.*?--(.*?)--(.*?)//(.*)", subPat) {
			version%A_Index% := subPat1, changes%A_Index% := subPat2, changelogText := subPat3
			StringReplace, changes%A_Index%, changes%A_Index%,`n,% "",0			
			allVersions .= version%A_Index% "|"
			allChanges.Insert(changes%A_Index%)
		}
		else
			break
	}

	labelPrefix := "Gui_About_"
	Gui, About:Destroy
	Gui, About:New, +HwndaboutGuiHandler +AlwaysOnTop +SysMenu -MinimizeBox -MaximizeBox +OwnDialogs +LabelGui_About_,% programName " by lemasato v" verCurrent

	translations := Get_Translations(A_ThisFunc)
	textContent := (isUpdateAvailable)?(translations.GB_UpdateAvailable " v" onlineVersionAvailable):(translations.GB_UpdateNotAvailable)
	Gui_Add({_Name:"About",_Font:"Segoe UI",_Type:"GroupBox",_Content:textContent,_Pos:"xm ym w500 h85",_Color:"Black",_Var:"GB_UpdateAvailable",_Opts:"Section"})
	Gui_Add({_Type:"Text",_Content:translations.TEXT_CurrentVersion A_Tab A_Tab verCurrent,_Pos:"xs+20 ys+20"})
	Gui_Add({_Type:"Text",_Content:translations.TEXT_LatestVersion A_Tab A_Tab ProgramValues.Version_Latest,_Handler:"hTXT_LatestVersion",_Pos:"xp y+5"})
	if (isUpdateAvailable) {
		Gui_Add({_Type:"Button",_Content:translations.BTN_Update,_Pos:"x+25 yp-3 h20"})
		Gui_Control("About", "+cBlue", GuiAbout_Controls.GB_UpdateAvailable)
		Gui_Control("About", "+cBlue", GuiAbout_Controls.TXT_LatestVersion)
	}
	Gui_Add({_Type:"Checkbox",_Content:translations.CB_EnableAutomaticUpdates,_Pos:"xs+20 y+8",_Var:"CB_AutoUpdate",_CB_State:isAutoUpdateEnabled})
	Gui_Add({_Type:"DropDownList",_Content:allVersions,_Pos:"xm y+20 w500",_Label:labelPrefix "DDL_OnVersionChoose",_Var:"DDL_Version",_Opts:"R10 AltSubmit"})
	Gui_Control("About", "Choose", GuiAbout_Controls.DDL_Version, "|1")
	Gui_Add({_Type:"Edit",_Pos:"xm y+5 wp",_Var:"EDIT_Changelogs",_Opts:"R15 ReadOnly"})
	Gui_Add({_Type:"Text",_Content:translations.TEXT_SeeOn,_Pos:"xm y+10"})
	Gui_Add({_Type:"Link",_Content:"<a href="""">GitHub</a>",_Pos:"x+5",_Label:"Link_GitHub"})
	Gui_Add({_Type:"Text",_Content:"-",_Pos:"x+5"})
	Gui_Add({_Type:"Link",_Content:"<a href="""">AHK Forums</a>",_Pos:"x+5",_Label:"Link_AHK"})
	Gui_Add({_Type:"Text",_Content:"-",_Pos:"x+5"})
	Gui_Add({_Type:"Link",_Content:"<a href="""">GitHub Wiki</a>",_Pos:"x+5",_Label:"Link_Github_Wiki"})
	Gui_Add({_Type:"Picture",_Content:paypalPicture,_Pos:"x435 yp-7",_Label:"Link_Paypal"})
	Gui, About:Show
	Return

	Gui_About_DDL_OnVersionChoose:
		GoSub Gui_About_Submit
		versionID := GuiAbout_Submit.DDL_Version
		Gui_Control("About", ,GuiAbout_Controls.EDIT_Changelogs, allChanges[versionID])
	Return



	Gui_About_Submit:
		Gui_Submit(GuiAbout_Controls, "About", "NoHide")
	Return
	
	Version_Change:
		Gui, About:Submit, NoHide
		GuiControl, About:,%ChangesTextHandler%,% allChanges[verNum]
		Gui, About:Show, AutoSize
	return

	Gui_About_Update:
		Download_Updater()
	Return

	Gui_About_Close:
		GoSub Gui_About_Submit

		IniWrite,% GuiAbout_Submit.CB_AutoUpdate,% iniFilePath,PROGRAM,Auto_Update
		Gui, About:Destroy
	Return
}

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
 *			MISC GUIS 																*
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
*/

Gui_GetControl(ctrlName) {
/*		Ask the user to click on a specific button so we can retrieve its ClassNN
*/
	global ProgramValues, ProgramSettings, NVIDIA_Values
	global GuiGetControl_Controls := {}
	global GuiGetControl_Submit := {}

	nvHandler := NVIDIA_Values.Handler

	translations := Get_Translations(A_ThisFunc)
	labelPrefix := "Gui_GetControl_"
	
	Gui, GetControl:Destroy
	Gui, GetControl:New, +AlwaysOnTop +SysMenu -MinimizeBox -MaximizeBox +OwnDialogs +LabelGui_GetControl_ +hwndhGuiGetControl,% ProgramValues.Name
	Gui_Add({_Name:"GetControl",_Font:"Segoe UI",_Type:"Text",_Content:translations.TEXT_AutoFailed})
	Gui_Add({_Type:"Link",_Content:"<a>" translations.TEXT_ClickForScreenshot "</a>",_Label:"Link_NVIDIA_Screenshot",_Pos:"y+5"})
	Gui_Add({_Type:"Text",_Content:translations.TEXT_Expected,_Pos:"xm y+25"})
	Gui_Add({_Type:"Edit",_Content:"Static2",_Pos:"xp+60 yp-5 w80",_Var:"EDIT_Expected",_Opts:"ReadOnly"})
	Gui_Add({_Type:"Text",_Content:translations.TEXT_Example,_Pos:"x+5"})
	Gui_Add({_Type:"Text",_Content:translations.TEXT_Retrieved,_Pos:"xm y+20"})
	Gui_Add({_Type:"Edit",_Pos:"xp+60 yp-5 w80",_Var:"EDIT_Retrieved",_Opts:"ReadOnly"})
	Gui_Add({_Type:"Button",_Content:translations.BTN_Accept,_Pos:"x+10 yp-7 w100 h30",_Label:labelPrefix "Accept",_Handler:"hBTN_Accept",_Opts:"ReadOnly +Disabled"})
	Gui_Add({_Type:"Text",_Content:translations.TEXT_Contribute,_Pos:"xm y+20"})
	Gui_Add({_Type:"Edit",_Pos:"xm w300",_Var:"EDIT_RetrievedText",_Opts:"ReadOnly"})
	Gui, GetControl:Show
	WinRestore, ahk_id %nvHandler%

	SetTimer, Gui_GetControl_Refresh, 100
	WinWait, ahk_id %hGuiGetControl%
	WinWaitClose, ahk_id %hGuiGetControl%
	
	return [retrieved, retrievedText]	
	
	Gui_GetControl_Close:
	return
	
	Gui_GetControl_Escape:
	return
	
	Gui_GetControl_Accept:
		Gui_Submit(GuiGetControl_Controls, "GetControl", "NoHide")
		retrieved 			:= GuiGetControl_Submit["EDIT_Retrieved"]
		retrievedText 		:= GuiGetControl_Submit["EDIT_RetrievedText"]
		expected 			:= GuiGetControl_Submit["EDIT_Expected"]

		if retrieved contains %expected%
		{
			SetTimer, Gui_GetControl_Refresh, Delete
			Gui, GetControl:Destroy
		}
	return
	
	Gui_GetControl_Refresh:
		KeyWait, LButton, D
		if !WinActive("ahk_exe nvcplui.exe")
			Return
		nvHandler := WinActive("ahk_exe nvcplui.exe")

		MouseGetPos, , , , ctrlName, ahk_id %nvHandler%
		ControlGetText, ctrlText,% ctrlName, ahk_id %nvHandler%
		if !(ctrlText)
			Return

		if ctrlName contains Static
		{
			Gui_Control("GetControl", ,GuiGetControl_Controls["EDIT_Retrieved"], ctrlName)
			Gui_Control("GetControl", ,GuiGetControl_Controls["EDIT_RetrievedText"], ctrlText)
			Gui_Control("GetControl", "-Disabled",GuiGetControl_Controls["BTN_Accept"])
		}
		else {
			Gui_Control("GetControl", "+Disabled",GuiGetControl_Controls["BTN_Accept"])
		}
	return 
}

GUI_Select_Language() {
/*		Lets the user choose whichever language suits the best
*/
	static
	global ProgramSettings, ProgramValues
	translations := Get_Translations("GUI_Select_Language")

	Gui, SelectLang:Destroy
	Gui, SelectLang:New, +AlwaysOnTop +SysMenu -MinimizeBox -MaximizeBox +OwnDialogs +LabelGUI_Select_Language_ +hwndGuiLangHandler,% ProgramValues.Name

	Gui, SelectLang:Add, Text, x10 y10,% translations.TXT_ChooseLanguage
	Gui, SelectLang:Add, DropDownList, x10 gGui_LangSelect_List_Event vlangListItem,% translations.DDL_AvailableLangs
	Gui, SelectLang:Add, Button, x10 y+20 h30 gGui_LangSelect_Apply hwndhApplyBtn,% translations.BTN_Apply

;	Select the previously selected lang
	lang := (lang)?(lang):("EN") ; Sets default lang
	Loop, Parse,% translations["DDL_AvailableLangs"],% "|"
	{
		RegExMatch(A_LoopField, "(.*)-", thisLangPat)
		if (thisLangPat1 = lang) {
			GuiControl, SelectLang:ChooseString,langListItem,% A_LoopField
		}
	}
	
	Gui, SelectLang:Show, AutoSize
	WinWait, ahk_id %GuiLangHandler%
	WinWaitClose, ahk_id %GuiLangHandler%
	return

	GUI_Select_Language_Size:
		GuiControl, SelectLang:Move,% hApplyBtn,% "w" A_GuiWidth-15
	Return
	
	Gui_LangSelect_List_Event:
;		Update the GUI language
		Gui, SelectLang:Submit, NoHide
		Gui, SelectLang:+OwnDialogs

;		Retrieve only the language tag
		RegExMatch(langListItem, "(.*)-", lang)
		StringTrimRight, lang, lang, 1

;		Set the language setting and reload GUI
		if !(ProgramSettings.SETTINGS)
			ProgramSettings.SETTINGS := {}
		ProgramSettings.SETTINGS.Language := lang
		GUI_Select_Language()
	return
	
	Gui_LangSelect_Apply:
		if (lang) {
			IniWrite,% lang,% ProgramValues.Ini_File,SETTINGS,Language
			Gui, SelectLang:Destroy
		}
	return
	
	Gui_LangSelect_Close:
	return
	
	Gui_LangSelect_Escape:
	return
}

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
 *			UPDATE CHECK AND UPDATING												*
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
*/

Download_Updater() {
	global ProgramValues

	IniWrite,% A_Now,% ProgramValues.Ini_File,PROGRAM,LastUpdate
	UrlDownloadToFile,% ProgramValues.Updater_Link,% ProgramValues.Updater_File
	Sleep 10
	if (!ErrorLevel) {
		Run,% ProgramValues.Updater_File 
		; Run,% A_ScriptDir "\Updater_v2.ahk"
		. " /Name=""" ProgramValues.Name  """"
		. " /File_Name=""" A_ScriptDir "\" ProgramValues.Name ".exe" """"
		. " /Local_Folder=""" ProgramValues.Local_Folder """"
		. " /Ini_File=""" ProgramValues.Ini_File """"
		. " /NewVersion_Link=""" ProgramValues.Version_Latest_Download """"
	}
	else {
		translations := Get_Translations("Tray_Notifications")
		Tray_Notifications_Show(translations.TITLE_UpdaterDownloadFailed, translations.MSG_UpdaterDownloadFailed)
	}
}

Check_Update() {
;			It works by downloading both the new version and the auto-updater
;			then closing the current instancie and renaming the new version
	global ProgramValues

	IniRead, isUsingBeta,% ProgramValues.Ini_File,PROGRAM,Update_Beta, 0
	IniRead, isAutoUpdateEnabled,% ProgramValues.Ini_File,PROGRAM,Auto_Update, 0
	IniRead, lastTimeUpdated,% ProgramValues.Ini_File,PROGRAM,LastUpdate,% A_Now

	changeslogsLink 		:= (isUsingBeta)?(ProgramValues.Changelogs_Link_Beta):(ProgramValues.Changelogs_Link)
	versionLinkStable 		:= ProgramValues.Version_Link
	versionLinkBeta 		:= ProgramValues.Version_Link_Beta
	currentVersion 			:= ProgramValues.Version

	translations := Get_Translations("Tray_Notifications")

;	Delete files remaining from updating
	if FileExist(ProgramValues.Updater_File)
		FileDelete,% ProgramValues.Updater_File
	if FileExist(ProgramValues.NewVersion_File)
		FileDelete,% ProgramValues.NewVersion_File
	if FileExist(A_ScriptDir "\gvUpdater.exe")
		FileDelete,% A_ScriptDir "\gvUpdater.exe"

;	Changelogs file
	Try {
		Changelogs_WinHttpReq := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		Changelogs_WinHttpReq.SetTimeouts("10000", "10000", "10000", "10000")

		Changelogs_WinHttpReq.Open("GET", changeslogsLink, true) ; Using true above and WaitForResponse allows the script to r'emain responsive.
		Changelogs_WinHttpReq.Send()
		Changelogs_WinHttpReq.WaitForResponse(10) ; 10 seconds

		changelogsOnline := Changelogs_WinHttpReq.ResponseText
		changelogsOnline = %changelogsOnline%
		if ( changelogsOnline ) && !( RegExMatch(changelogsOnline, "Not(Found| Found)") ){
			try 
				FileRead, changelogsLocal,% ProgramValues.Changelogs_File
			catch e
				Logs_Append("DEBUG_STRING", {String:"[WARNING]: Failed to read file """ ProgramValues.Changelogs_File """. Does the file exist?"})
			if ( changelogsLocal != changelogsOnline ) {
				try
					FileDelete, % ProgramValues.Changelogs_File
				catch e
					Logs_Append("DEBUG_STRING", {String:"[WARNING]: Failed to delete file """ ProgramValues.Changelogs_File """. Does the file exist?"})
				UrlDownloadToFile, % changeslogsLink,% ProgramValues.Changelogs_File
			}
		}
	}
	Catch e {
;		Error Logging
		Logs_Append("WinHttpRequest", {Obj:e})
		Tray_Notifications_Show(translations.TITLE_ChangelogsDownloadFailed, translations.MSG_ChangelogsDownloadFailed)
	}

; Releases API
	Try {
		Releases_WinHttpReq := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		Releases_WinHttpReq.SetTimeouts("10000", "10000", "10000", "10000")

		Releases_WinHttpReq.Open("GET", "https://api.github.com/repos/" ProgramValues.Github_User "/" ProgramValues.GitHub_Repo "/releases?page=1", true)
		Releases_WinHttpReq.Send()
		Releases_WinHttpReq.WaitForResponse(10)

		releasesJSON := Releases_WinHttpReq.ResponseText
		parsedReleases := JSON.Load(releasesJSON)
		latestReleaseTag := parsedReleases[1]["tag_name"]
		latestReleaseDownload := parsedReleases[1]["assets"][1]["browser_download_url"]
	}
	Catch e {
		Logs_Append("WinHttpRequest", {Obj:e})
		Tray_Notifications_Show(translations.TITLE_ReleasesAPIFailed, translations.MSG_ReleasesAPIFailed)

		latestReleaseTag 		:= "ERROR"
		latestReleaseDownload 	:= ""
	}

/*
;	Version.txt on master branch
	Try {
		Version_WinHttpReq := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		Version_WinHttpReq.SetTimeouts("10000", "10000", "10000", "10000")

		Version_WinHttpReq.Open("GET", versionLinkStable, true)
		Version_WinHttpReq.Send()
		Version_WinHttpReq.WaitForResponse(10)

		versionOnline := Version_WinHttpReq.ResponseText
		versionOnline = %versionOnline%
		if ( versionOnline ) && !( RegExMatch(versionOnline, "Not(Found| Found)") ) { ; couldn't reach the file, cancel update
			StringReplace, versionOnline, versionOnline, `n,,1 ; remove the 2nd white line
			versionOnline = %versionOnline% ; remove any whitespace
		}
	}
	Catch e {
;		Error Logging
		Logs_Append("WinHttpRequest", {Obj:e})
		Tray_Notifications_Show(translations.TITLE_VersionFileDownloadFailed, translations.MSG_VersionFileDownloadFailed)
	}
*/
;	Set version IDs
	; latestStableVersion 	:= (versionOnline)?(versionOnline):("ERROR")
	; latestStableVersion = %latestStableVersion%

	latestReleaseTag := (latestReleaseTag)?(latestReleaseTag):("ERROR")
	latestReleaseDownload := (latestReleaseDownload)?(latestReleaseDownload):("ERROR")

	ProgramValues.Version_Latest 			:= latestReleaseTag
	ProgramValues.Version_Online 			:= latestReleaseTag
	ProgramValues.Version_Latest_Download 	:= latestReleaseDownload
	latestStableVersion 					:= latestReleaseTag

;	Set new version number and notify about update
	isUpdateAvailable := (latestStableVersion != "ERROR" && latestStableVersion != currentVersion && latestStableVersion)?(1):(0)
	ProgramValues.Update_Available := isUpdateAvailable

	if ( isUpdateAvailable ) {
		if (isAutoUpdateEnabled = 1) {
			timeDif := A_Now
			EnvSub, timeDif,% lastTimeUpdated, Seconds
			if (timeDif > 61 || !timeDif) { ; !timeDif means var was not in YYYYMMDDHH24MISS format 
				Tray_Notifications_Show(ProgramValues.Version_Online . translations.TITLE_VersionAvailable, translations.MSG_VersionAvailable_AutoUpdate)
				Download_Updater()
			}
		}
		else {
			Tray_Notifications_Show(ProgramValues.Version_Online translations.TITLE_VersionAvailable, translations.MSG_VersionAvailable, {Is_Update:1, Fade_Timer:20000, Is_Important:1})
		}
	}
	SetTimer, Check_Update, -10800000 ; 3 hours
}

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
 *			LOCAL SETTINGS															*
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
*/

Get_GameProfiles_Settings() {
	global ProgramValues

	IniRead, allSections,% ProgramValues.Ini_File
	mySettings := {}
	Loop, Parse, allSections,% "`n`r"
	{
		if RegExMatch(A_LoopField, ".exe") {
			mySettings[A_LoopField] := {}
			IniRead, gammaVal,% ProgramValues.Ini_File,% A_LoopField,Gamma
			IniRead, vibranceVal,% ProgramValues.Ini_File,% A_LoopField,Vibrance

			mySettings[A_LoopField]["Gamma"] := gammaVal
			mySettings[A_LoopField]["Vibrance"] := vibranceVal

		}
	}

	return mySettings
}

Declare_GameProfiles_Settings(settings) {
	global GameProfiles, ProgramValues, GameList

	GameList := ""

	for _section, nothing in settings { ; For every section in the settings array

		GameList .= "," _section

		subArr := settings[_section] ; Declare the subArray for this section so we can access its keys
		if !(GameProfiles[_section]) { ; Create the sub-array if non-existent
			GameProfiles[_section] := {}
		}

		for iniKey, value in subArr { ; For every keys in the subArray
			if IsNum(settings[_section][iniKey]) { ; As long as the value exists, add to the global GameProfiles array
				GameProfiles[_section][iniKey] := value
			}
			else { ; Invalid value
				Logs_Append("DEBUG_STRING", {String:"[WARNING] Unable to declare setting " _section "." iniKey " with value: " value "."})
			}
		}
	}

	StringTrimLeft, GameList, GameList, 1 ; Remove first comma
}

Update_Local_Settings() {
/*	Cross-release changes that need updating
*/
	global ProgramValues
	iniFile := ProgramValues.Ini_File

;	This setting is unreliable in cases where the user updates to 1.12 (or higher) then reverts back to pre-1.12 since the setting was only added as of 1.12
	IniRead, priorVer,% iniFile,% "PROGRAM",% "Version",% "UNKNOWN"
	priorVerNum := (priorVer="UNKNOWN")?(ProgramValues.Version):(priorVer)

	subVersions := StrSplit(priorVersionNum, ".")
	mainVer := subVersions[1], releaseVer := subVersions[2], patchVer := subVersions[3]

;	Example. This will handle changes that happened between 2.1 and current.
	if (mainVer = 2 && releaseVer < 1) {

	}

	priorVer := "UNKNOWN"
	if (priorVer = "UNKNOWN") { ; Pre 2.1 settings.

		; Remove these settings as they have been placed in PROGRAM now
		IniDelete,% iniFile, SETTINGS, PID
		IniDelete,% iniFile, SETTINGS, FileName
		IniDelete,% iniFile, SETTINGS, AutoUpdate
		; Remove these aswell, no longer used
		IniDelete,% iniFile, SETTINGS, StartHidden
		IniDelete,% iniFile, SETTINGS, MonitorID

		; Rename these settings, they are now in a new section
		keys := ["AdjustDesktopCtrl","AdjustDesktopCtrlText","Path"]
		newKeys := ["Control_AdjustDesktop","Control_AdjustDesktopText","Location"]
		for id, iniKey in keys {
			IniRead, value,% iniFile,SETTINGS,% iniKey
			if (value != "ERROR" && value != "") {
				IniDelete,% iniFile, SETTINGS,% iniKey
				IniWrite,% value,% iniFile,NVIDIA_PANEL,% newKeys[id]
			}
		}
	}

	IniRead, openChangelogs,% iniFile,PROGRAM,Show_Changelogs, 0
	if ( openChangelogs = 1 ) {
		Check_Update()
		Gui_About()
		IniWrite, 0,% iniFile,PROGRAM,Show_Changelogs
	}
}

Set_Local_Settings() {
/*		Set local settings, specific to the application
*/
	global ProgramValues
	static iniFile

	iniFile := ProgramValues.Ini_File

;	Set the PID and filename, used for the auto updater
	IniWrite,% ProgramValues.PID,% iniFile,PROGRAM,PID
	IniWrite,% """" A_ScriptName """",% iniFile,PROGRAM,FileName

	HiddenWindows := A_DetectHiddenWindows
	DetectHiddenWindows On
	WinGet, fileProcessName, ProcessName,% "ahk_pid " ProgramValues.PID
	IniWrite,% """" fileProcessName """",% iniFile,PROGRAM,FileProcessName
	DetectHiddenWindows, %HiddenWindows%

;	Set current version, used for Update_Local_Settings()
	IniWrite,% ProgramValues.Version,% iniFile,% "PROGRAM",% "Version"

;	Delete empty section, if existing
	IniDelete,% ProgramValues.Ini_File,% ""
}

Get_Local_Settings() {
/*		Retrieve the local settings
 *		If setting does not exist, set its default value
*/
	global ProgramValues
	static iniFile

	iniFile 			:= ProgramValues.Ini_File
	settings 			:= {}

;	PROGRAM
	IniRead, value,% iniFile,PROGRAM,Auto_Update
	if ( value = "ERROR" ||value = "" ) {
		IniWrite, 1,% iniFile,PROGRAM,Auto_Update
	}

;	SETTINGS
	keys 		:= ["Language","RunOnStartup"]
	defValues 	:= ["",0]
	for id, iniKey in keys {
		IniRead, value,% iniFile,SETTINGS,% iniKey
		if ( value = "ERROR" || value = "" ) {
			value := defValues[id]
			IniWrite,% value,% iniFile,SETTINGS,% iniKey
		}
		if (iniKey = "Language" && value = "") {
			value := GUI_Select_Language()
		}
		settings.SETTINGS[iniKey] := value
	}

;	NVIDIA_PANEL
	keys 		:= ["Control_AdjustDesktop","Control_AdjustDesktopText","Location"]
	for id, iniKey in keys {
		IniRead, value,% iniFile,NVIDIA_PANEL,% iniKey
		if ( value = "ERROR" || value = "") {
			value := ""
		}
		settings.NVIDIA_PANEL[iniKey] := value
	}

;	DEFAULT
	keys 		:= ["Gamma","Vibrance"]
	for id, iniKey in keys {
		IniRead, value,% iniFile,DEFAULT,% iniKey
		if ( value = "ERROR" || value = "") {
			value := (iniKey = "Gamma")?(100):(iniKey = "Vibrance")?(50):("")
			IniWrite,% value,% iniFile,DEFAULT,% iniKey
		}
		settings.DEFAULT[iniKey] := value
	}

;	HOTKEYS
	keys 		:= ["GammaPlus","GammaMinus","VibrancePlus","VibranceMinus","TriggerAndSave"]
	subKeys 	:= ["ALT","CTRL","SHIFT","WIN"]
	for id, iniKey in keys {
		; The hotkey itself
		IniRead, value,% iniFile,HOTKEYs,% iniKey
		if (value = "ERROR") {
			value := ""
			IniWrite,% value,% iniFile,HOTKEYS,% iniKey
		}
		settings.HOTKEYS[iniKey] := value
		; Its modifiers
		for id, subIniKey in subKeys {
			IniRead, value,% iniFile,HOTKEYS,% iniKey . subIniKey
			if (value = "ERROR" || value = "") {
				value := "0"
				IniWrite,% value,% iniFile,HOTKEYS,% iniKey . subIniKey
			}
			settings.HOTKEYS_MODIFIERS[iniKey . subIniKey] := value
		}
	}

	return settings
}

Declare_Local_Settings(settings) {
/*		Declare the settings to a global variable
*/
	global ProgramSettings, ProgramValues

	for _section, nothing in settings { ; For every section in the settings array

		subArr := settings[_section] ; Declare the subArray for this section so we can access its keys
		if !(ProgramSettings[_section]) { ; Create the sub-array if non-existent
			ProgramSettings[_section] := {}
		}

		for iniKey, value in subArr { ; For every keys in the subArray
			if (settings[_section][iniKey] != "ERROR") { ; As long as the value exists, add to the global ProgramSettings array
				ProgramSettings[_section][iniKey] := value
			}
			else { ; This should never trigger as values are handled by another function. BUT YOU NEVER KNOW.... YOU NEVER KNOW
				Msgbox,4096,% ProgramValues.Name, % "Unable to declare setting: " _section "." iniKey " with value: " value 
													. "`nPlease report this issue."
			}
		}
	}
}

Save_Temporary_GameProfiles(whichApp="ALL") {
	global GameProfiles, ProgramSettings, ProgramValues

	iniFile := ProgramValues.Ini_File

;	Save all apps settings, if they already have an existing profile and the setting differ from the ini
	if (whichApp = "ALL") {
		for app, nothing in GameProfiles {
			IniRead, gamma,% iniFile,% app, Gamma
			IniRead, vibrance,% iniFile,% app, Vibrance
			if (gamma != "" && gamma != "ERROR") && (vibrance != "" && vibrance != "ERROR") {
				if (GameProfiles[app]["Gamma"] != gamma )
			  		IniWrite,% GameProfiles[app]["Gamma"],% iniFile,% app,Gamma 
				if (GameProfiles[app]["Vibrance"] != vibrance)
					IniWrite,% GameProfiles[app]["Vibrance"],% iniFile,% app,Vibrance
			}
		}
	}
;	Write a specific app settings, if they differ from the ini
	else {
		thisApp_gamma 		:= GameProfiles[whichApp]["Gamma"]
		thisApp_Vibrance 	:= GameProfiles[whichApp]["Vibrance"]

		IniRead, gamma,% iniFile,% app, Gamma
		if (gamma != thisApp_gamma && IsNum(thisApp_gamma))
			IniWrite,% thisApp_gamma,% iniFile,% whichApp,Gamma
		IniRead, vibrance,% iniFile,% app, Vibrance
		if (vibrance != thisApp_Vibrance && IsNum(thisApp_Vibrance))
			IniWrite,% thisApp_Vibrance,% iniFile,% whichApp,Vibrance
	}
}

Extract_Assets() {
/*		Include assets in the executable and extract them to their respective folder on launch
*/
	global ProgramValues

	FileInstall, Resources\Others\icon.ico,% ProgramValues.Others_Folder "\icon.ico", 1
	FileInstall, Resources\Others\DonatePaypal.png,% ProgramValues.Others_Folder "\DonatePaypal.png", 1
	FileInstall, Resources\Translations.json,% ProgramValues.Local_Folder "\Translations.json", 1
}

Update_Startup_Shortcut() {
/*		Update the startup shortcut, or remove it if disabled
*/
	global ProgramSettings, ProgramValues

	FileDelete, % A_Startup "\" ProgramValues.Name ".lnk" ; Remove the old shortcut

	if (ProgramSettings.SETTINGS.RunOnStartup) { ; Place new shortcut, if enabled
		FileCreateShortcut,% A_ScriptFullPath,% A_Startup "\" ProgramValues.Name ".lnk"
	}
}

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
 *			HOTKEYS 																*
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
*/

Enable_Hotkeys() {
	;	Enable the hotkeys, based on its global VALUE_ content
	global ProgramSettings, ProgramValues, ProgramHotkeys

	ProgramHotkeys := {}
	programName := ProgramValues.Name, iniFilePath := ProgramValues.Ini_File

	for hotkeyName, boundKey in ProgramSettings.HOTKEYS {
		finalHotkey := ""
		modCTRL 	:= ProgramSettings.HOTKEYS_MODIFIERS[hotkeyName "CTRL"]
		modALT 		:= ProgramSettings.HOTKEYS_MODIFIERS[hotkeyName "ALT"]
		modSHIFT 	:= ProgramSettings.HOTKEYS_MODIFIERS[hotkeyName "SHIFT"]
		modWIN 		:= ProgramSettings.HOTKEYS_MODIFIERS[hotkeyName "WIN"]

		if (boundKey != "") {
			finalHotkey .= (modCTRL)?("^"):("")
			finalHotkey .= (modALT)?("!"):("")
			finalHotkey .= (modSHIFT)?("+"):("")
			finalHotkey .= (modWIN)?("#"):("")
			finalHotkey .= boundKey

			ProgramHotkeys[hotkeyName] := finalHotkey
			Hotkey,% finalHotkey, Hotkeys_Handler, On
		}
	}
}


Hotkeys_Handler() {
	global ProgramHotkeys, ProgramSettings, GameProfiles, GameList, ExcludedProcesses
	static gamma, vibrance, activeEXE, prev_activeEXE

;	Multiple hotkeys, same key
	for hotkeyName, boundKey in ProgramHotkeys {
		for compare_hotkeyName, compare_boundKey in ProgramHotkeys {
			if (hotkeyName != compare_hotkeyName && boundKey = A_ThisHotkey) {
				if hotkeyName not in %actions%
					actions .= hotkeyName ","
			}
			else if hotkeyName not in %actions%
				actions .= hotkeyName ","
		}
	}
	StringTrimRight, actions, actions, 1 ; Remove last comma

	WinGet, activeEXE, ProcessName, A
	if activeExe in %ExcludedProcesses%
		Return

	if (activeEXE != prev_activeEXE) {
		thisAppGamma := GameProfiles[activeEXE]["Gamma"], thisAppVibrance := GameProfiles[activeEXE]["Vibrance"]
		gammaLastNum := SubStr(thisAppGamma, 0, 1), vibranceLastNum := SubStr(thisAppVibrance, 0, 1)
		if (gammaLastNum != 5)
			thisAppGamma := thisAppGamma-gammaLastNum+5
		if (vibranceLastNum != 5)
			thisAppVibrance := thisAppVibrance-vibranceLastNum+5

		gamma := (thisAppGamma)?(thisAppGamma):(ProgramSettings.DEFAULT.Gamma)
		vibrance := (thisAppVibrance)?(thisAppVibrance):(ProgramSettings.DEFAULT.Vibrance)
	}

	currentMon := GetMonitorIndexFromWindow(), currentMon--
	if actions contains GammaPlus
	{
		gamma := (IsBetween(gamma+5, 30, 280))?(gamma+5):(gamma)
		NVIDIA_Set_Settings(gamma, "prev", currentMon, 0, 1)
	}
	if actions contains GammaMinus
	{
		gamma := (IsBetween(gamma-5, 30, 280))?(gamma-5):(gamma)
		NVIDIA_Set_Settings(gamma, "prev", currentMon, 0, 1)
	}

	if actions contains VibrancePlus
	{
		vibrance := (IsBetween(vibrance+5, 0, 100))?(vibrance+5):(vibrance)
		NVIDIA_Set_Settings("prev", vibrance, currentMon, 0, 1)
	}
	if actions contains VibranceMinus
	{
		vibrance := (IsBetween(vibrance-5, 0, 100))?(vibrance-5):(vibrance)
		NVIDIA_Set_Settings("prev", vibrance, currentMon, 0, 1)
	}
	if actions contains TriggerAndSave
	{
		WinGet, winExe, ProcessName, A
		Set_ThisApp_Settings(winExe,1)
		Save_Temporary_GameProfiles(winExe)
	}

	if !GameProfiles[activeEXE]
		GameProfiles[activeEXE] := {}
	GameProfiles[activeEXE]["Gamma"] := gamma, GameProfiles[activeEXE]["Vibrance"] := vibrance
	if activeEXE not in %GameList%
		GameList .= "," activeEXE

	prev_activeEXE := activeEXE
}

Disable_Hotkeys() {
	;	Enable the hotkeys, based on its global VALUE_ content
	global ProgramSettings, ProgramValues, ProgramHotkeys

	for hotkeyName, boundKey in ProgramHotkeys {
		try Hotkey,% boundKey, Hotkeys_Handler, Off
	}
}
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
 *			LOGS FILE																*
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
*/

Logs_Append(funcName, params) {
	global ProgramValues, ProgramSettings, GameProfiles

	programName := ProgramValues.Name
	programVersion := ProgramValues.Version
	iniFilePath := ProgramValues.Ini_File
	logsFile := ProgramValues.Logs_File

	if ( funcName = "START" ) {
		FileDelete,% logsFile

		OSbits := (A_Is64bitOS)?("64bits"):("32bits")
		IniRead, programSectionContent,% iniFilePath,PROGRAM

		gameSettingsContent := ""
		for key, element in GameProfiles {
			if (gameSettingsContent)
				gameSettingsContent .= "`n"
			gameSettingsContent .= key "`nGamma: " GameProfiles[key]["Gamma"] "`nVibrance: " GameProfiles[key]["Vibrance"] "`n"
		}

		paramsKeysContent := ""
		for key, element in params.KEYS {
			paramsKeysContent .= params.KEYS[A_Index] ": """ params.VALUES[A_Index] """`n"
		}

		appendToFile := ""
		appendToFile := ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>`n"
						. ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>`n"
						. ">>> OS SECTION `n"
						. ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>`n"
						. "Type: " A_OSType "`n"
						. "Version: " A_OSVersion "(" OSbits ")`n"
						. "DPI: " dpiFactor "`n"
						. "`n"
						. ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>`n"
						. ">>> TOOL SECTION `n"
						. ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>`n"
						. "Version: " ProgramValues.Version "`n"
						. "Local_Folder: " ProgramValues.Local_Folder "`n"
						. "Game_Folder: " ProgramValues.Game_Folder "`n"
						. "`n"
						. ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>`n"
						. ">>> PROGRAM SECTION `n"
						. ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>`n"
						. programSectionContent "`n"
						. "`n"
						. ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>`n"
						. ">>> GAME PROFILES `n"
						. ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>`n"
						. gameSettingsContent 
						. "`n"
						. ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>`n"
						. ">>> LOCAL SETTINGS `n"
						. ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>`n"
						. paramsKeysContent
						. "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<`n"
						. "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<`n"
	}

	else {
		appendToFile := "[" A_YYYY "/" A_MM "/" A_DD " " A_Hour ":" A_Min ":" A_Sec "] "

		if ( funcName = "DEBUG_STRING" ) {
			appendToFile := params.String
		}

		else if (funcName = "ShellMessage" ) {
			appendToFile .= "Trades GUI Hidden: Show_Mode: " params.Show_Mode " - Dock_Window ID: " params.Dock_Window " - Current Win ID: " params.Current_Win_ID "."
		}

	}

	if (appendToFile) {
		FileAppend,% appendToFile "`n",% logsFile
	}
}


Get_Running_Apps(_detectHiddenWin=false, _excludedProcesses="", _separator="") {
	global ExcludedProcesses

	hiddenWindows := A_DetectHiddenWindows
	_detectHiddenWin := (_detectHiddenWin=true)?("On"):(_detectHiddenWin=false)?("Off"):(_detectHiddenWin)
	DetectHiddenWindows,% _detectHiddenWin

	if (_excludedProcesses && _separator) {
		_excludedProcesses := StrReplace(_excludedProcesses, _separator, ",")
	}
	_excludedProcesses .= ExcludedProcesses

	WinGet, allWindows, List
	Loop, %allWindows% 
	{ 
		WinGetTitle, winTitle, % "ahk_id " allWindows%A_Index%
		WinGet, winExe, ProcessName, %winTitle%
		if (winExe) { ; Hide those who dont have a process attached
			if winExe not in %_excludedProcesses%
			{
				winList .= winExe " // " winTitle "`n"
			}
		}
	}
	Sort, winList, U ; Sort alphabetically and remove dupes

	DetectHiddenWindows,% hiddenWindows

	Return winList

}
/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
 *			TRAY ICON MENU															*
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
*/

Create_Tray_Menu() {	
/*		Create the tray menu
*/
	global ProgramValues, NVIDIA_Values
	static tranlations_Hide

	translations := Get_Translations("Tray_Menu")
	tranlations_Hide := translations.Hide

	Menu, Tray, DeleteAll
	Menu, Tray, NoStandard

	Menu, Tray, Tip,% ProgramValues.Name
	Menu, Tray, Add,% translations.Settings, Gui_Settings
	Menu, Tray, Add,% translations.About, Gui_About
	Menu, Tray, Add, 
	Menu, Tray, Add,% translations.Hide, Tray_Hide
	Menu, Tray, Check,% translations.Hide
	Menu, Tray, Add
	Menu, Tray, Add,% translations.Reload, Reload_Func
	Menu, Tray, Add,% translations.Close, Exit_Func
	if (A_IconHidden) {
		Menu, Tray, NoIcon
		Menu, Tray, Icon
	}
	if ( !A_IsCompiled && FileExist(A_ScriptDir "\icon.ico") )
		Menu, Tray, Icon,% A_ScriptDir "\icon.ico"
	return

	Tray_Hide: 
		hiddenWin := A_DetectHiddenWindows
		if WinExist("ahk_id " NVIDIA_Values.Handler) {
			Menu, Tray, Check,% tranlations_Hide
			WinHide,% "ahk_id " NVIDIA_Values.Handler
		}
		else {
			DetectHiddenWindows, On
			Menu, Tray, UnCheck,% tranlations_Hide
			WinShow,% "ahk_id " NVIDIA_Values.Handler
		}
		DetectHiddenWindows, %hiddenWin%
	return
}

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
 *			TRAY NOTIFICATIONS														*
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
*/

Tray_Notifications_Adjust(fromNum, creationOrder) {
	global TrayNotifications_Handles

	RegExMatch(fromNum, "\d", fromNum)

	Loop, Parse, creationOrder,% ","
	{
		reverse := A_LoopField "," reverse
	}

	Loop, Parse, reverse,% "," 
	{
		if (A_LoopField) {
			
			if (gotem) {
				
				WinGetPos, , pY, , pH,% "ahk_id " TrayNotifications_Handles[previous]
				WinGetPos, , tY, , tH,% "ahk_id " TrayNotifications_Handles[A_LoopField]
				formula := (previous = fromNum)?(pY-(tH-pH)):(py-tH-10)
				; msgbox Moving %A_Loopfield% to %previous% - %creationOrder% - %reverse%
				WinMove,% "ahk_id " TrayNotifications_Handles[A_LoopField], , ,% formula
			}
			if (A_LoopField = fromNum)
				gotEm := true
			else {
				newOrder .= A_Loopfield ","
			}

			previous := A_Loopfield
		}
	}

	creationOrder := StrReplace(creationOrder, fromNum, "", "")
	Loop, Parse, creationOrder,% ","
	{
		if (A_LoopField)
			finalOrder .= A_LoopField ","
	}

	Return finalOrder
}

Tray_Notifications_Show(title, msg, params="") {
/*		Show a notification.
 *		Look based on w10 traytip.
*/
	static
	global SkinAssets, ProgramSettings, ProgramValues
	global TrayNotifications_Handles

;	Don't show on fullscreen app. Cause an alt-tab on W10. Can't say for other OS.
	isActiveFullscreen := Is_Window_FullScreen()
	if (isActiveFullscreen)
		Return

;	Monitor infos
	local MonitorCount, MonitorPrimary, MonitorWorkArea
	local MonitorWorkAreaTop, MonitorWorkAreaBottom, MonitorWorkAreaLeft, MonitorWorkAreaRight
	SysGet, MonitorCount, MonitorCount
	SysGet, MonitorPrimary, MonitorPrimary
	SysGet, MonitorWorkArea, MonitorWorkArea,% MonitorPrimary

	; Calculating GUI size, based on content
	titleWidthMax := 310, textWidthMax := 330
	guiFontName := "Segoe UI", guiFontSize := "9", guiTitleFontSize := "10"
	titleSize := Get_Text_Control_Size(title, guiFontName, guiTitleFontSize, titleWidthMax)
	textSize := Get_Text_Control_Size(msg, guiFontName, guiFontSize, textWidthMax)


	; Declaring gui size
	guiWidth 	:= 350
	guiHeight 	:= (titleSize.H+5) + (textSize.H+20) ; 5=top margin, 20=title/msg margin
	borderSize 	:= 1
	
	; Get first avaialble notification to replace
	index := 1
	Loop 5 {
		local winHandle := TrayNotifications_Handles[A_Index]
		if WinExist("ahk_id " winHandle) {
			index++
		}
		else Break
	}
	; Create a list of order of creation, as long as we didnt reach the max of 5 notifications
	if !(index > 5) {
		creationOrder .= index ","
	}
	; We reached the max. So we replace the oldest available notification.
	else {
		index := SubStr(creationOrder,1,1)
		StringTrimLeft, creationOrder, creationOrder, 2
		creationOrder .= index ","
	}
	; Make sure the list doesn't go beyond 10 chars (5 number and 5 comma)
	len := StrLen(creationOrder)
	if (len > 10) {
		StringTrimRight, creationOrder, creationOrder,% len-10
	}

	; Parameters
	fadeTimer := (params.Fade_Timer)?(params.Fade_Timer):(8000)
	_label := (params.Is_Update)?("Gui_TrayNotification_OnLeftClick_Updater"):("Gui_TrayNotification_OnLeftClick")


	Gui, TrayNotification%index%:Destroy
	Gui, TrayNotification%index%:New, +ToolWindow +AlwaysOnTop -Border +LastFound -SysMenu -Caption +LabelGui_TrayNotification_ +hwndhGuiTrayNotification%index%

	if !(TrayNotifications_Handles)
		TrayNotifications_Handles := {}
	TrayNotifications_Handles[index] := hGuiTrayNotification%index%
	

	Gui, TrayNotification%index%:Margin, 0, 0
	Gui, TrayNotification%index%:Color, 1f1f1f

	Gui, TrayNotification%index%:Add, Progress, x0 y0 w%guiWidth% h%borderSize% Background484848 ; Top
	Gui, TrayNotification%index%:Add, Progress, x0 y0 w%borderSize% h%guiHeight% Background484848 ; Left
	Gui, TrayNotification%index%:Add, Progress,% "x" guiWidth-borderSize " y0" " w" borderSize " h" guiHeight " Background484848" ; Right
	Gui, TrayNotification%index%:Add, Progress,% "x" 0 " y" guiHeight-borderSize " w" guiWidth " h" borderSize " Background484848" ; Bottom
	Gui, TrayNotification%index%:Add, Text,% "x0 y0 w" guiWidth " h" guiHeight " BackgroundTrans g" _label,% ""

	Gui, TrayNotification%index%:Font, S%guiTitleFontSize% Bold,% guiFontName
	Gui, TrayNotification%index%:Add, Text,% "xm+35" " ym+9" " w" titleWidthMax " BackgroundTrans cFFFFFF",% title
	Gui, TrayNotification%index%:Font, S%guiFontSize% Norm,% guiFontName
	Gui, TrayNotification%index%:Add, Text,% "xm+10" " ym+35" " w" textWidthMax " BackgroundTrans ca5a5a5",% msg
	Gui, TrayNotification%index%:Add, Picture, x5 y5 w24 h24 hwndhIcon,% ProgramValues.Others_Folder "\icon.ico"

	showX := MonitorWorkAreaRight-guiWidth-10
	showY := MonitorWorkAreaBottom-guiHeight-10
	showW := guiWidth, showH := guiHeight
	Gui, TrayNotification%index%:Show,% "x" showX " y" showY " w" showW " h" showH " NoActivate"

	Loop 5 {
		if (A_Index != index ) {
			local winHandle := TrayNotifications_Handles[A_Index]
			if WinExist("ahk_id " winHandle) {
				WinGetPos, , _y, , _h, ahk_id %winHandle%
				WinMove, ahk_id %winHandle%, , ,% _y-guiHeight-10
			}
		}
	}

	Tray_Notifications_Fade(index, true)
	SetTimer, Gui_TrayNotification_Fade_%index%, -%fadeTimer%
	Return

	Gui_TrayNotification_Fade_1:
		ret1 := Tray_Notifications_Fade(1)
		if (ret1) {
			SetTimer, %A_ThisLabel%, -50
		}
		else {
			creationOrder := Tray_Notifications_Adjust(1, creationOrder)
			Gui, TrayNotification1:Destroy
		}
	Return
	Gui_TrayNotification_Fade_2:
		ret2 := Tray_Notifications_Fade(2)
		if (ret2) {
			SetTimer, %A_ThisLabel%, -50
		}
		else {
			creationOrder := Tray_Notifications_Adjust(2, creationOrder)
			Gui, TrayNotification2:Destroy
		}
	Return
	Gui_TrayNotification_Fade_3:
		ret3 := Tray_Notifications_Fade(3)
		if (ret3) {
			SetTimer, %A_ThisLabel%, -50
		}
		else {
			creationOrder := Tray_Notifications_Adjust(3, creationOrder)
			Gui, TrayNotification3:Destroy
		}
	Return
	Gui_TrayNotification_Fade_4:
		ret4 := Tray_Notifications_Fade(4)
		if (ret4) {
			SetTimer, %A_ThisLabel%, -50
		}
		else {
			creationOrder := Tray_Notifications_Adjust(4, creationOrder)
			Gui, TrayNotification4:Destroy
		}
	Return
	Gui_TrayNotification_Fade_5:
		ret5 := Tray_Notifications_Fade(5)
		if (ret5) {
			SetTimer, %A_ThisLabel%, -50
		}
		else {
			creationOrder := Tray_Notifications_Adjust(5, creationOrder)
			Gui, TrayNotification5:Destroy
		}
	Return

	Gui_TrayNotification_ContextMenu: ; Launched whenever the user right-clicks anywhere in the window except the title bar and menu bar.
		creationOrder := Tray_Notifications_Adjust(A_Gui, creationOrder)
		Gui, %A_GUI%:Destroy
	Return

	Gui_TrayNotification_OnLeftClick:
		creationOrder := Tray_Notifications_Adjust(A_Gui, creationOrder)
		Gui, %A_Gui%:Destroy
	Return

	Gui_TrayNotification_OnLeftClick_Updater:
		creationOrder := Tray_Notifications_Adjust(A_Gui, creationOrder)
		Gui, %A_Gui%:Destroy
		Download_Updater()
	Return
}

Tray_Notifications_Fade(index="", start=false) {
	static

	if (start) {
		transparency%index% := 240 ; Set initial transparency
		; Return
	}

	transparency%index% := (0 > transparency%index%)?(0):(transparency%index%-15)
	
	Gui, TrayNotification%index%:+LastFound
	WinSet, Transparent,% transparency%index%
	return transparency%index%
}

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
 *			MISC FUNCTIONS 															*
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
*/

ShellMessage_State(state) {
	Gui, ShellMsg:Destroy
	Gui, ShellMsg:New, +LastFound 

	Hwnd := WinExist()
	DllCall( "RegisterShellHookWindow", UInt,Hwnd )
	MsgNum := DllCall( "RegisterWindowMessage", Str,"SHELLHOOK" )
	OnMessage( MsgNum, "ShellMessage", state)
}

Check_Conflicting_Applications() {
/*		Check possible running or installed applications causing conflict
*/
	global ProgramValues

	EnvGet, LocalAppdata, LocalAppData
	translations := Get_Translations("Tray_Notifications")

	Process, Exist, flux.exe
	if (ErrorLevel)
		trayMsg .= translations.MSG_Conflict_Flux
	if FileExist(LocalAppdata "\FluxSoftware\Flux\flux.exe")
		installed .= "flux,"

	StringTrimRight, installed, installed, 1 ; Remove last comma
	StringTrimRight, running, running, 1 ; Remove last comma

	if (trayMsg)
		Tray_Notifications_Show(ProgramValues.Name,trayMsg,{Fade_Timer:20000})

	return
}

Close_Previous_Program_Instance() {
/*
 *			Prevents from running multiple instances of this program
 *			Works by reading the last PID and process name from the .ini
 *				, checking if there is an existing match
 *				and closing if a match is found
*/
	global ProgramValues

	iniFilePath := ProgramValues.Ini_File

	IniRead, lastPID,% iniFilePath,PROGRAM,PID
	IniRead, lastProcessName,% iniFilePath,PROGRAM,FileProcessName

	translations := Get_Translations(A_ThisFunc)

	Process, Exist, %lastPID%
	existingPID := ErrorLevel
	if ( existingPID = 0 )
		Return ; No match found
	else {
		HiddenWindows := A_DetectHiddenWindows
		DetectHiddenWindows, On ; Required to access the process name
		WinGet, existingProcessName, ProcessName, ahk_pid %existingPID% ; Get process name from PID
		DetectHiddenWindows, %HiddenWindows%
		if ( existingProcessName = lastProcessName ) { ; Match found, close the previous instance
			Process, Close, %existingPID%
			Process, WaitClose, %existingPID%, 5
			ClosePrevious_Error:
			if (ErrorLevel) { ; Unable to close process due to lack of admin  
				MsgBox, 4096, ProgramValues.Name,% translations.TEXT_UnableToClose
				Process, Exist, %existingPID%
				if (Exists)
					GoSub ClosePrevious_Error
			}
		}
	}
}

Get_Translations(_section) {
	global ProgramValues, ProgramSettings

	lang := (ProgramSettings.SETTINGS.Language)?(ProgramSettings.SETTINGS.Language):("EN")
	translations := {}

;	Using JSON
	jsonFile := ProgramValues.Local_Folder "\Translations.json"
	FileRead, jsonContent,% jsonFile
	parsed_JSON := Json.Load(jsonContent)

	translations[_section][lang] := parsed_JSON[_section][lang]
	for key, element in parsed_JSON[_section]["EN"]{
		this_translation := parsed_JSON[_section][lang][key]
		if (!this_translation) {
			this_translation := parsed_JSON[_section]["EN"][key] ; if inexistent, use EN instead
		}
		this_translation := StrReplace(this_translation, "``n", "`n")
		this_translation := StrReplace(this_translation, "%programName%", ProgramValues.Name)

		translations[key] := this_translation
	}
	return translations
/*
;	Using INI
	IniRead, allSettings,% ProgramValues.Translations_File,% _section
	Loop, Parse,% allSettings,% "`n`r"
	{
		keyAndValue := A_LoopField
		if RegExMatch(keyAndValue, "(.*?)_(.*?)=""(.*)""", found) {
			thisLang := found1, thisKey := found2, thisSetting := found3
			thisSetting := StrReplace(thisSetting, "``n", "`n")

			if (thisLang = lang) {
				translations[thisKey] := thisSetting
			}

			found1 := "", found2 := "", found3 := ""
			thisLang := "", thisKey := "", thisSetting := ""
		}
	}

	for key

	return translations
*/
}

ShellMessage(wParam,lParam) {
/*			Triggered upon activating a window
 *			Is used to correctly position the Trades GUI while in Overlay mode
*/
	global NVIDIA_Values
	global NVIDIA_Set_Settings_FullScreen_CANCEL
	global NVIDIA_Set_Settings_FullScreen_START
	global NVIDIA_Set_Settings_FullScreen_HANDLE

	if ( wParam=4 or wParam=32772 ) { ; 4=HSHELL_WINDOWACTIVATED | 32772=HSHELL_RUDEAPPACTIVATED
		WinGet, winExe, ProcessName,% "ahk_id " lParam
		Set_ThisApp_Settings(winExe)
		if (NVIDIA_Set_Settings_FullScreen_START && lParam != NVIDIA_Set_Settings_FullScreen_HANDLE) {
			NVIDIA_Set_Settings_FullScreen_CANCEL := true
		}
	}
}

Is_Window_FullScreen(_handle="") {
;			Detects if the window is fullscreen
;			 by checking its style and size
	if (_handle = "") {
		WinGet, _handle, ID, A
	}
	WinGet _Style, Style, ahk_id %_handle%
	WinGetPos, , , w, h, ahk_id %_handle%
	state := ( (_Style & 0x20800000) || h < A_ScreenHeight || w < A_ScreenWidth ) ? false : true
	return state
}

IsNum(str) {
	if str is number
		return true
	return false
}

IsBetween(value, first, last) {
   if value between %first% and %last%
      return true
   else
      return false
}

Get_Control_Coords(guiName, ctrlHandler) {
/*		Retrieve a control's position and return them in an array.
		The reason of this function is because the variable content would be blank
			unless its sub-variables (coordsX, coordsY, ...) were set to global.
			(Weird AHK bug)
*/
	GuiControlGet, coords, %guiName%:Pos,% ctrlHandler
	return {X:coordsX,Y:coordsY,W:coordsW,H:coordsH}
}

Get_Text_Control_Size(txt, fontName, fontSize, maxWidth="") {
/*		Create a control with the specified text to retrieve
 *		the space (width/height) it would normally take
*/
	Gui, GetTextSize:Font, S%fontSize%,% fontName
	if (maxWidth) 
		Gui, GetTextSize:Add, Text,x0 y0 +Wrap w%maxWidth% hwndTxtHandler,% txt
	else 
		Gui, GetTextSize:Add, Text,x0 y0 hwndTxtHandler,% txt
	coords := Get_Control_Coords("GetTextSize", TxtHandler)
	Gui, GetTextSize:Destroy

	return coords

/*	Alternative version, with auto sizing

	Gui, GetTextSize:Font, S%fontSize%,% fontName
	Gui, GetTextsize:Add, Text,x0 y0 hwndTxtHandlerAutoSize,% txt
	coordsAuto := Get_Control_Coords("GetTextSize", TxtHandlerAutoSize)
	if (maxWidth) {
		Gui, GetTextSize:Add, Text,x0 y0 +Wrap w%maxWidth% hwndTxtHandlerFixedSize,% txt
		coordsFixed := Get_Control_Coords("GetTextSize", TxtHandlerFixedSize)
	}
	Gui, GetTextSize:Destroy

	if (maxWidth > coords.Auto)
		coords := coordsAuto
	else
		coords := coordsFixed

	return coords
*/
}

Tray_Refresh() {
/*		Remove any dead icon from the tray menu
 *		Should work both for W7 & W10
 */
	WM_MOUSEMOVE := 0x200
	detectHiddenWin := A_DetectHiddenWindows
	DetectHiddenWindows, On

	allTitles := ["ahk_class Shell_TrayWnd"
			, "ahk_class NotifyIconOverflowWindow"]
	allControls := ["ToolbarWindow321"
				,"ToolbarWindow322"
				,"ToolbarWindow323"
				,"ToolbarWindow324"]
	allIconSizes := [24,32]

	for id, title in allTitles {
		for id, controlName in allControls
		{
			for id, iconSize in allIconSizes
			{
				ControlGetPos, xTray,yTray,wdTray,htTray,% controlName,% title
				y := htTray - 10
				While (y > 0)
				{
					x := wdTray - iconSize/2
					While (x > 0)
					{
						point := (y << 16) + x
						PostMessage,% WM_MOUSEMOVE, 0,% point,% controlName,% title
						x -= iconSize/2
					}
					y -= iconSize/2
				}
			}
		}
	}

	DetectHiddenWindows, %detectHiddenWin%
}

GetMonitorIndexFromWindow(windowHandle="") {
/*		Credits: shinywong
 *		autohotkey.com/board/topic/69464-how-to-determine-a-window-is-in-which-monitor/?p=440355
 *
 *		Retrieve the monitor ID, based on window position.
 *		Index starts at 1
*/
	if (!windowHandle) {
		windowHandle := WinActive("A")
	}
	monitorIndex := 1

	VarSetCapacity(monitorInfo, 40)
	NumPut(40, monitorInfo)
	
	if (monitorHandle := DllCall("MonitorFromWindow", "uint", windowHandle, "uint", 0x2)) 
		&& DllCall("GetMonitorInfo", "uint", monitorHandle, "uint", &monitorInfo) 
	{
		monitorLeft   := NumGet(monitorInfo,  4, "Int")
		monitorTop    := NumGet(monitorInfo,  8, "Int")
		monitorRight  := NumGet(monitorInfo, 12, "Int")
		monitorBottom := NumGet(monitorInfo, 16, "Int")
		workLeft      := NumGet(monitorInfo, 20, "Int")
		workTop       := NumGet(monitorInfo, 24, "Int")
		workRight     := NumGet(monitorInfo, 28, "Int")
		workBottom    := NumGet(monitorInfo, 32, "Int")
		isPrimary     := NumGet(monitorInfo, 36, "Int") & 1

		SysGet, monitorCount, MonitorCount

		Loop, %monitorCount%
		{
			SysGet, tempMon, Monitor, %A_Index%

			; Compare location to determine the monitor index.
			if ((monitorLeft = tempMonLeft) and (monitorTop = tempMonTop)
				and (monitorRight = tempMonRight) and (monitorBottom = tempMonBottom))
			{
				monitorIndex := A_Index
				break
			}
		}
	}
	
	return %monitorIndex%
}

Reload_Func() {
	global NVIDIA_Values

	Sleep 10
	Reload
	Sleep 10000
}

Exit_Func(ExitReason, ExitCode) {
	global NVIDIA_Values, ProgramSettings
	static closing

	ShellMessage_State(0)

	if (closing) {
		closing := false
		Return
	}

	closing := true
	SysGet, MonitorCount, MonitorCount
	Loop %MonitorCount% {
		NVIDIA_Set_Settings(ProgramSettings.DEFAULT.Gamma, ProgramSettings.DEFAULT.Vibrance, A_Index, 0, 1)
		Sleep 100
	}
	Process, Close,% NVIDIA_Values.PID
	Process, Close, nvcplui.exe
	ExitApp
}

Link_GitHub:
	Run,% ProgramValues.Link_GitHub
Return
Link_GitHub_Wiki:
	Run,% ProgramValues.Link_Github_Wiki
Return
Link_AHK:
	Run,% ProgramValues.Link_AHK
Return
Link_Paypal:
	Run,% ProgramValues.Link_Github_Wiki "/Support"
Return
Link_NVIDIA_Screenshot:
	Run, ProgramValues.Link_NVIDIA_Screenshot
Return

#Include %A_ScriptDir%\Resources\AHK
#Include JSON.ahk
#Include Gui_Funcs.ahk
#Include Class_NvAPI.ahk