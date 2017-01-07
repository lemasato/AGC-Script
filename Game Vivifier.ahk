/* 
	Game Vivifier by masato
	Allows NVIDIA users to have custom gamma/vibrance profiles for their game
	https://autohotkey.com/boards/viewtopic.php?t=9455
	https://github.com/lemasato/Game-Vivifier
*/

OnExit("Exit_Func")
#SingleInstance Off
#SingleInstance Force ; uncomment this line when using .ahk version
SetWorkingDir, %A_ScriptDir%
;===============================

;___Some variables___;
global userprofile
EnvGet, userprofile, userprofile
global programVersion := "2.0.13" , programName := "Game Vivifier", programLang
global iniFilePath := userprofile "\Documents\AutoHotKey\" programName "\Preferences.ini"
global nvHandler, nvPath, nvStatic, nvStaticText, programPID

;___Creating .ini Dir___;
if !( InStr(FileExist("\Documents\AutoHotkey"), "D") )
	FileCreateDir, % userprofile "\Documents\AutoHotkey"
if !( InStr(FileExist("\Documents\AutoHotkey\" programName ), "D") )
	FileCreateDir, % userprofile "\Documents\AutoHotkey\" programName

;___Functions calls___;
Prevent_Multiple_Instancies()
settingsArray := Get_Settings_From_Ini()
runHidden := settingsArray[1], autoUpdate := settingsArray[2], programLang := settingsArray[3], nvStatic := settingsArray[4], nvStaticText := settingsArray[5], settingsArray := ""
Create_Tray_Menu(programLang)
Update_Startup_Shortcut()
Check_Update(autoUpdate)
nvPath := Get_NVCPL_Path()
nvHandler := Run_NVCPL()
Check_nvStatic_Valid()
nvHandler := Run_NVCPL(1)
Program_TrayTip()

;___Window Switch Detect___;
Gui +LastFound 
Hwnd := WinExist()
DllCall( "RegisterShellHookWindow", UInt,Hwnd )
MsgNum := DllCall( "RegisterWindowMessage", Str,"SHELLHOOK" )
OnMessage( MsgNum, "ShellMessage" )
return

ShellMessage( wParam,lParam )
{
	if ( wParam=4 or wParam=32772 ) { ; 4=HSHELL_WINDOWACTIVATED | 32772=HSHELL_RUDEAPPACTIVATED
		WinGet, winEXE, ProcessName, ahk_id %lParam%
		if ( winExe <> "autohotkey.exe" && winExe <> "nvcplui.exe" && winExe <> A_ScriptName) {
			userPrefs := Get_Preferences_From_Ini(winEXE) ; [gamma, vibrance, gammaDef, vibranceDef]
			Switch(winEXE, winTitle, userPrefs[1], userPrefs[2], userPrefs[3], userPrefs[4], userPrefs[5])
		}
	}
}

;==================================================================================================================
;
;																															FUNCTIONS
;
;==================================================================================================================

Switch(process, title, gVal, cVal, gDef, cDef, monitorID=0) {
;			Apply gamma/vibrance preferences.
;			Values are minus one because we press RIGHT (+1) to register the message.
;			If fullscreen application is detected, send the message 10 times with 2s delay.
	handler := nvHandler

	DetectHiddenWindows, On
	if !( WinExist("ahk_id " handler ) ) { ; User most likely closed the window
		timer := 3
		Loop 3 {
			TrayTip,% programName " couldn't find`nNVCPL window's handler`n`nThe program will restart in " timer "..."
			sleep 1000
			timer--
		}
		Reload_Func()
	}
	PostMessage, 0x0405,0,% gVal -1,msctls_trackbar323, ahk_id %handler%
	ControlSend,msctls_trackbar323, {Blind}{Right}, ahk_id %handler%
	NvApi.SetDVCLevelEx(cVal, monitorID)
	isFullscreen := Is_Window_Fullscreen(process, title)
	if ( isFullScreen ) && ( ( gVal <> gDef  ) || ( cVal <> cDef ) ) {
		waitSec := A_Sec+5, times := 0
		Loop {
			if ( times >= 6 ) || !( WinActive("ahk_exe" process) )
				break
			if ( ( waitSec >= 59 ) && ( A_Sec < 10 ) ) || ( ( waitSec > 50 ) && ( A_Sec < 10 ) )
				waitSec -= 60
			if ( A_Sec >= waitSec ) || ( ( A_Sec < 10 ) && ( waitSec > 50 ) ) {
					PostMessage, 0x0405,0,% gVal -2,msctls_trackbar323, ahk_id %handler%
					ControlSend,msctls_trackbar323, {Blind}{Right 2}, ahk_id %handler%
					PostMessage, 0x0405,0,% gVal -1,msctls_trackbar323, ahk_id %handler%
					ControlSend,msctls_trackbar323, {Blind}{Right}, ahk_id %handler%
					NvApi.SetDVCLevelEx(cVal, monitorID)
					waitSec := A_Sec+5, times++
			}
			sleep 100
		}
	}
	DetectHiddenWindows, Off
}

Get_Settings_From_Ini() {
;			Creates the ini file, sets the broken/unexistent values
;				Return the settings
	path := iniFilePath

	programPID := DllCall("GetCurrentProcessId")
	IniWrite,% programPID,% iniFilePath,SETTINGS,PID
	IniWrite,% A_ScriptName,% path,SETTINGS,FileName
	
	IniRead, runOnStart,% path,SETTINGS,RunOnStartup
	if ( runOnStart = "ERROR" || runOnStart = "" ) {
		IniWrite, 0,% path,SETTINGS,RunOnStartup
		IniRead, runOnStart,% path,SETTINGS,RunOnStartup
	}
	
	IniRead, runHidden,% path,SETTINGS,StartHidden
	if ( runHidden = "ERROR" || runHidden = "" ) {
		IniWrite, 1,% path,SETTINGS,StartHidden
		IniRead, runHidden,% path,SETTINGS,StartHidden
	}
	
	IniRead, gDef,% path,DEFAULT,Gamma
	if ( gDef = "ERROR" || gDef = "" ) {
		IniWrite, 100,% path,DEFAULT,Gamma
		IniRead, gDef,% path,DEFAULT,Gamma
	}
	
	IniRead, vDef,% path,DEFAULT,Vibrance
	if ( vDef ="ERROR" || vDef = "" ) {
		IniWrite, 50,% path,DEFAULT,Vibrance
		IniRead, vDef,% path,DEFAULT,Vibrance
	}
	
	IniRead, auto,% path,SETTINGS,AutoUpdate
	if ( auto = "ERROR" || auto = "" ) {
		IniWrite, 0,% path,SETTINGS,AutoUpdate
		IniRead, auto,% path,SETTINGS,AutoUpdate
	}
	
	IniRead, lang, % path,SETTINGS,Language
	if ( lang = "ERROR" || lang = "" ) {
		lang := Gui_LangSelect()
		IniWrite,% lang,% path,SETTINGS,Language
		IniRead, lang, % path,SETTINGS,Language
	}
	
	IniRead, staticCtrl,% path,SETTINGS,AdjustDesktopCtrl
	if staticCtrl not contains Static
	{
		IniWrite,% "",% iniFilePath,SETTINGS,AdjustDesktopCtrl
		IniRead, staticCtrl,% path,SETTINGS,AdjustDesktopCtrl		
	}
	
	IniRead, staticCtrlText,% path,SETTINGS,AdjustDesktopCtrlText
	if ( staticCtrlText = "ERROR" || staticCtrlText = "" ) {
		IniWrite,% "",% iniFilePath,SETTINGS,AdjustDesktopCtrlText
		IniRead, staticCtrlText,% path,SETTINGS,AdjustDesktopCtrlText
	}
	
	IniRead, defaultMonitor,% iniFilePath,SETTINGS,Monitor_ID
	if ( defaultMonitor = "ERROR" || defaultMonitor = "" ) {
		IniWrite,% "0",% iniFilePath,SETTINGS,Monitor_ID
		IniRead, defaultMonitor,% iniFilePath,SETTINGS,Monitor_ID
	}
	
	return [runHidden, auto, lang, staticCtrl, staticCtrlText]
}

Get_Preferences_From_Ini(process) {
;			Retrieves the preferences from the .ini, returns them
;			If no preferences have been set, default one will be returned
	IniRead, x, %iniFilePath%, %process%, Gamma
	IniRead, x2, %iniFilePath%, %process%, Vibrance
	if ( x = "ERROR" || x = "" || x2 = "ERROR" || x2 = "" )	; no preferences found, we get the defaut one instead
	{
		IniRead, gamma, %iniFilePath%, DEFAULT, Gamma
		IniRead, vibrance, %iniFilePath%, DEFAULT, Vibrance
	}
	else ; preferences found, retrieve them
	{
		IniRead, gamma, %iniFilePath%, %process%, Gamma
		if gamma is not integer
			IniRead, gamma, %iniFilePath%, DEFAULT, Gamma
		
		IniRead, vibrance, %iniFilePath%, %process%, Vibrance
		if vibrance is not integer
			IniRead, vibrance, %iniFilePath%, DEFAULT, Vibrance
	}
	IniRead, gammaDef, %iniFilePath%, DEFAULT, Gamma
	IniRead, vibranceDef, %iniFilePath%, DEFAULT, Vibrance
	if ( gammaDef = "ERROR" || gammaDef = "" )
		gammaDef := 100
	if ( vibranceDef = "ERROR" || vibranceDef ="" )
		vibranceDef := 50		
	if ( gamma = "ERROR" || gamma = "" )
		gamma := 100
	if ( vibrance = "ERROR" || vibrance ="" )
		vibrance := 50
	
	IniRead, defaultMonitor,% iniFilePath,SETTINGS,Monitor_ID
	return [gamma, vibrance, gammaDef, vibranceDef, defaultMonitor]
} 

Get_NVCPL_Path() {
;			Retrieve the NVCPL location and runs it
;			If unable to find it, ask the user to point its location
	IniRead, path,% iniFilePath,SETTINGS,Path
	if ( path = "ERROR" || path = "" ) { 	;	Try to find nvcplui.exe, based on 32/64 OS
		EnvGet, progFiles, ProgramW6432
		if ( progFiles = )
			EnvGet, progFiles, ProgramFiles
		path := progFiles "\NVIDIA Corporation\Control Panel Client\nvcplui.exe"
	}
	if !( FileExist( path ) ) {
;		Couldn't find, ask the user to locate it manually
		MsgBox, 0x40030,% programName " - WARNING: nvcplui.exe not found",Couldn't find nvcplui.exe!`n`nUpon closing this window, you will be asked to locate it manually`nThe file should be located under:`n"Program Files\NVIDIA Corporation\Control Panel Client\nvcplui.exe"
		FileSelectFile, path, 3, %progFiles%, Please go to \NVIDIA Corporation\Control Panel Client\nvcplui.exe, nvcplui.exe
		if ( ErrorLevel = 1 ) {
			Reload_Func()
		}
	}
	IniWrite,% path,% iniFilePath, SETTINGS,Path
	return path
}

Run_NVCPL(clickIt=0) {
;			Control IDs are generated dynamically as the user goes trough the NVCPL
;				Therefore, we have to make sure the first tab clicked is the one we need
;				So all the control names can be predicted
	path := nvPath, staticCtrl := nvStatic
	
	Process, Close, nvcplui.exe
	Process, WaitClose, nvcplui.exe
	Run, %path%, ,Min ,procID
	WinWait, ahk_pid %procID%
	WinGet, handler, ID, ahk_pid %procID%
	if ( staticCtrl ) {
		ControlClick, %staticCtrl%, ahk_id %handler%
		sleep 100
	}
	if ( clickIt ) {
		ControlClick, Button4, ahk_id %handler% ; "Use NVIDIA settings" button
		WinHide, ahk_id %handler%
	}
	return handler
}

Check_nvStatic_Valid() {
;			Make sure the control used for nvStatic is valid
;			It works by checking if the gamma/vibrance sliders are available
;			If they are not, ask the user to point the control again.
	handler := nvHandler, staticCtrl := nvStatic, staticCtrlText := nvStaticText
	transArray := Get_Translation("Check_nvStatic", programLang)
	
	WinShow, ahk_id %handler%
	WinWait, ahk_id %handler%
	while (ctrlText = "") { ; Get the current nvStatic control text
		ControlGetText, ctrlText, %staticCtrl%, ahk_id %handler%
		if ( a_index > 100 )
			break
	}
	if ( staticCtrl = "ERROR" || staticCtrl = "" || staticCtrlText = "ERROR" || staticCtrlText = "" || ctrlText <> nvStaticText ) {
		Get_nvStatic_Auto()
	}
	Loop {
;		Make sure the window responds to the ControlClick
		ControlClick, %staticCtrl%, ahk_id %handler% ; Failed, click the tab again, in case it wasn't active already
		if ( errorlvl = "clear323-324" )
			break
		if ( errorlvl <> "clear323" && errorlvl <> "clear323-324" ) {
			PostMessage, 0x0405,0, ,msctls_trackbar323, ahk_id %handler% ; Attempt to reach the slider control
			if ( ErrorLevel )
				ControlClick, %staticCtrl%, ahk_id %handler% ; Failed, click the tab again, in case it wasn't active already
			else 
				errorlvl := "clear323" ; Succeesfully reached the control, can be skipped from the check from now
		}
		if ( errorlvl <> "clear-323-324" ) {
			PostMessage, 0x0405,0, ,msctls_trackbar324, ahk_id %handler% ; Attempt to reach the slider control
			if ( ErrorLevel )
				ControlClick, %staticCtrl%, ahk_id %handler% ; Failed, click the tab again, in case it wasn't active already
			else 
				if ( errorlvl = "clear323" ) ; First check already succeed
					errorlvl := "clear323-324" ; Succeesfully reached the control, can be skipped from the check from now
		}
		if ( A_Index > 100 ) { ; More than 100 attempts to reach the sliders controls failed.
			TrayTip
			Get_nvStatic_Auto() ; We attempt to retrieve the tab control automatically.
			
		}
		if ( A_Index > 20 ) ; Checks are still in progress
			TrayTip,% programName,% transArray[1] "`n" A_Index " / 100" transArray[2]
		sleep 100
	}
}

Get_nvStatic_Auto() {
;			Tries to retrive the control ID automatically
;			It's attempts are based on the control's text
	i := 1, rtrn := "", handler := nvHandler
	ctrlTextFR := "Régler les paramètres des couleurs du bureau", ctrlTextEN := "Adjust desktop color settings", i := 1
	
	Loop {
		ControlGetText, ctrlText, Static%i%, ahk_exe nvcplui.exe
		if ( ctrlText = "" )
			while ( ctrlText = "" ) { ; The window is most likely not responding, so we try until we get something
				ControlGetText, ctrlText,Static%i%, ahk_id %handler%
				sleep 100
			}
		if ( ctrlText = ctrlTextFR || ctrlText = ctrlTextEN ) {
			rtrn := "Ctrl_Found"
			break
		}
		if ( i > 10 ) {
			rtrn := "Ctrl_Not_Found"
			break
		}
		sleep 100
		i++
	}
	if ( rtrn = "Ctrl_Found" ) {
		ctrlStatic := "Static" i, ctrlStaticText := ctrlText
		IniWrite,Static%i%,% iniFilePath,SETTINGS,AdjustDesktopCtrl
		IniWrite,% ctrlStaticText,% iniFilePath,SETTINGS,AdjustDesktopCtrlText
		Reload_Func()
	}
	else if ( rtrn = "Ctrl_Not_Found" ) {	; Couldn't find automatically. User probably has nvcpl in another language than the supported list. We ask the user to locate it
		ctrlArray := Gui_Get_Control("Adjust desktop color settings")
		ctrlStatic := ctrlArray[1], ctrlStaticText := ctrlArray[2]
		IniWrite,% ctrlStatic,% iniFilePath,SETTINGS,AdjustDesktopCtrl
		IniWrite,% ctrlStaticText,% iniFilePath,SETTINGS,AdjustDesktopCtrlText
		Reload_Func()
	}
}
	
Is_Window_FullScreen(process, title) {
;			Detects if the window is fullscreen
;			 by checking its style and size
	hwnd := WinExist( title " ahk_exe " process )
	WinGet style, Style, ahk_id %hwnd%
	WinGetPos, , , w, h, ahk_id %hwnd%
	state := ( (style & 0x20800000) || h < A_ScreenHeight || w < A_ScreenWidth ) ? false : true
	return state
}

Prevent_Multiple_Instancies() {
;			Prevent from running multiple instancies of the program
;			Check if an instancie already exist and close the current instancie if so
	IniRead, runningProcess,% iniFilePath,SETTINGS,FileName
	Process, Exist, %runningProcess%
	runningPID := ErrorLevel
	if ( runningPID ) {
		currentPID := DllCall("GetCurrentProcessId")
		if ( runningPID <> currentPID ) {
			OnExit("Exit_Func", 0)
			ExitApp	
		}
	}
}

;==================================================================================================================

Get_Translation(sect, lang, ctrlName="") {
;			Retrieve the translation for that specific section
;			Returns an array
;			Update the Tray Menu, unless it's the section
	if ( lang = "" )
		lang := "EN"
	if ( sect <> "Tray_Menu" )
		Create_Tray_Menu(lang)
	
;	GUI Control and their translation
	if ( sect = "Gui_Lang" ) {
		if ( lang = "EN" ) {
			text1 := "Select a language:", text2 := "Can changed anytime from the [Settings] menu.", text3 := "|EN-English|FR-French", text4 := "Apply"
		}
		if ( lang = "FR" ) {
			text1 := "Choisissez une langue:", text2 := "Peut être changée depuis le menu [Options].", text3 := "|EN-Anglais|FR-Français", text4 := "Appliquer"
		}
	}
	if ( sect = "Gui_Settings" ) {
		if ( lang = "EN" ) {
			text1 := "Run the program on system startup?", text2 := "Language:", text3 := "|EN-English|FR-French", text4 := "Hidden`nWindows", text5 := "Refresh"
			text6 := "Help?", text7 := "Gamma", text8 := "Default", text9 := "Vibrance", text10 := "Default", text11 := "Monitor ID:"
		}
		if ( lang = "FR" ) {
			text1 := "Démarrer le programme au démarrage?", text2 := "Langue:", text3 := "|EN-Anglais|FR-Français", text4 := "Fenètres`nCachées", text5 := "Actualiser"
			text6 := "Aide?", text7 := "Gamma", text8 := "Défaut", text9 := "Vibrance", text10 := "Défaut", text11 := "ID Écran:"
		}
	}
	if ( sect = "Gui_About" ) {
		transArray := Get_Translation("Tray_Menu", lang) ; 1: Settings
		transArray2 := Get_Translation("Gui_Settings", lang) ; 6: Help
		if ( lang = "EN" ) {
			text1  := "Hello, thank you for using " programName "!", text2 := "It allows NVIDIA GPU owners to have custom gamma/vibrance profiles for their games.`n" "Say goodbye to the old boring global profile!"
			text3:= "If you would like to get started, select [" transArray[1] "] from the tray menu.`n" "Once over there, hover the [" transArray2[6] "] button to get some instructions."
			text4 := "<a href=""https://github.com/lemasato/Game-Vivifier"">See on GitHub</a>", text5 := "<a href=""https://autohotkey.com/boards/viewtopic.php?t=9455"">See on AutoHotKey Forums</a>"
		}
		
		if ( lang = "FR" ) {
			text1 := "Bonjour, merci d'utiliser " programName "!", text2 := "Il permet aux possésseurs de GPU NVIDIA d'avoir des profiles personnalisés pour leur jeux.`n" "Dites adieu au fastidieux profile global unique!"
			text3 := "Si vous souhaitez commencer, choisissez [" transArray[1] "] depuis le menu de barre d'état`n" "Une fois celà fait, passez le curseur sur le bouton [" transArray2[6] "] pour obtenir des instructions."
			text4 := "<a href=""https://github.com/lemasato/Game-Vivifier"">Voir sur GitHub</a>", text5 := "<a href=""https://autohotkey.com/boards/viewtopic.php?t=9455"">Voir sur AutoHotKey Forums</a>"
		}
	}
	if ( sect = "Gui_Update" ) {
		if ( lang = "EN" ) {
			text1 := "Would you like to update now?"
			text2 := "The process is automatic, only your permission is required."
			text3 := "Accept", text4 := "Refuse", text5 := "Open the download page"
			text6 := "Receive updates automatically from now"
		}
		if ( lang = "FR" ) {
			text1 := "Voudriez-vous mettre à jour maintenant?"
			text2 := "Le procédé est auto, seule votre permission est requise."
			text3 := "Accepter", text4 := "Refuser", text5 := "Ouvrir la page de téléchargement"
			text6 := "Recevoir les prochaines mises à jour automatiquement"
		}
	}
	if ( sect = "Gui_Get_Control" ) {
		if ( lang = "EN" ) {
			text1 := "Couldn't retrieve the control ID for ''" ctrlName "''!`nYou will have to manually click on it."
			text2 := "This error is because your NVCPL's language is different than [EN/FR]."
			text3 := "Please, wait for the NVIDIA Control Panel to open`nthen click on " ctrlName "."
			text4 := ">> Click to see an helpful screenshot <<", text5 := "Control retrieved:", text6 := "Expected (example):"
			text7 := "If you wish to help in making the process automatic for your language,`nplease post the content of the box below on the autohotkey.com thread! (CLICK)"
			text8 := "VALIDATE"
		}
		if ( lang = "FR" ) {
			text1 := "Impossible de récupérer l'ID pour ''" ctrlName "''!`nVous devrez cliquer manuellement dessus."
			text2 := "Cette erreur est due à la langue du NVCPL étant différente de [EN/FR]."
			text3 := "Veuillez attendre l'ouverture du Panneau de configuration NVIDIA,`npuis cliquez sur " ctrlName "."
			text4 := ">> Cliquer pour voir un screenshot <<", text5 := "Control récupéré:", text6 := "Présumé (example):"
			text7 := "Si vous souhaitez aider à rendre le procédé automatisé pour votre language,`nveuillez poster le contenu ci-dessous sur le sujet autohotkey.com! (CLICK)"
			text8 := "VALIDER"
		}
	}
	if ( sect = "Tray_Tip" ) {
		transArray := Get_Translation("Tray_Menu", lang) ; 1: Settings - 2:About
		if ( lang = "EN" ) {
			text1 := "Right click on the tray icon then`n>> [" transArray[1] "] for profiles.`n>> [" transArray[2] "] for infos."
		}
		if ( lang = "FR" ) {
			text1 := "Clic droit sur l'icône puis`n>>[" transArray[1] "] pour les profiles.`n>>[" transArray[2] "] pour des infos."
		}
	}
	if ( sect = "Tray_Menu" ) {
		if ( lang = "EN" ) {
			text1 := "Settings", text2 := "About?", text3 := "NVCPL Hidden", text4 := "Reload", text5 := "Close"
		}
		if ( lang = "FR" ) {
			text1 := "Options", text2 := "À Propos?", text3 := "NVCPL Caché", text4 := "Recharger", text5 := "Quitter"
		}
	}
	if ( sect = "Program_Exit" ) {
		if ( lang = "EN" ) {
			text1 := "Do you really wish to close " programName "?"			
		}
		if ( lang = "FR" ){
			text1 := "Souhaitez-vous vraiment fermer " programName "?"
		}
	}
	if ( sect = "Check_nvStatic") {
		if ( lang = "EN" ) {
			text1 := "Currently checking if the control is valid.", text2 := " Faileds."
		}
		if ( lang = "FR" ) {
			text1 := "Vérification du control en cours.", text2 := " Echouées."
		}
	}
	textArray := []
	Loop {
		if ( text%A_Index% <> "" )
			textArray.InsertAt(A_Index, text%A_Index%)
		else break
	}
	return textArray
}

Set_Translation(sect, lang, handlers, trans) {
	if ( sect = "Gui_Lang" ) {
		Loop {
			if ( handlers[A_Index] = "" )
				break
			GuiControl, Lang:,% handlers[A_Index],% trans[A_Index]
			if ( A_Index = 3 ) && ( lang = "EN" )
				GuiControl, Choose,% handlers[A_Index],1
			if ( A_Index = 3 ) && ( lang = "FR" )
				GuiControl, Choose,% handlers[A_Index],2
		}
	}
	if ( sect = "Gui_Settings" ) {
		Loop {
			if ( handlers[A_Index] = "" )
				break
			GuiControl, Settings:,% handlers[A_Index],% trans[A_Index]
			if ( A_Index = 3 ) && ( lang = "EN" )
				GuiControl, Choose,% handlers[A_Index],1
			if ( A_Index = 3 ) && ( lang = "FR" )
				GuiControl, Choose,% handlers[A_Index],2
		}
	}
	if ( sect = "Gui_About" ) {
		Loop {
			if ( handlers[A_Index] = "" )
				break
			GuiControl, About:,% handlers[A_Index],% trans[A_Index]
		}
	}
	if ( sect = "Gui_Update" ) {
		Loop {
			if ( handlers[A_Index] = "" )
				break
			GuiControl, Update:,% handlers[A_Index],% trans[A_Index]
		}
	}
	if ( sect = "Gui_Get_Control" ) {
		Loop {
			if ( handlers[A_Index] = "" )
				break
			GuiControl, GetControl:,% handlers[A_Index],% trans[A_Index]
		}
	}
}

;==================================================================================================================

Update_Startup_Shortcut() {
;			Remove the old shortcut and place the new one
;			Or just remove it if it isn't supposed to run on startup anymore
	IniRead, state,% iniFilePath,SETTINGS,RunOnStartup
	if ( state ) {
		FileDelete, % A_Startup "\" programName ".lnk"
		FileCreateShortcut, % A_ScriptFullPath, % A_Startup "\" programName ".lnk"
	}
	else {
		FileDelete, % A_Startup "\" programName ".lnk"
	}
}

Program_TrayTip() {
;			Show a tray tip upon successful launch to notify the user
	transArray := Get_Translation("Tray_Tip", programLang)
	TrayTip,% programName " v" programVersion,% transArray[1]
}

WM_MOUSEMOVE() {
;			Taken from Alpha Bravo. Shows tooltip upon hovering a gui control
;			https://autohotkey.com/board/topic/81915-solved-gui-control-tooltip-on-hover/#entry598735
	static
	curControl := A_GuiControl
	If ( curControl <> prevControl ) {
		SetTimer, Display_ToolTip, -300 	; shorter wait, shows the tooltip quicker
		prevControl := curControl
	}
	return
	
	Display_ToolTip:
		try
			ToolTip, % %programLang%_%curControl%_TT
		catch
			ToolTip,
		if ( curControl = "helpMe" )
			SetTimer, Remove_ToolTip, -20000
		else
			SetTimer, Remove_ToolTip, -2000
	return
	
	Remove_ToolTip:
		ToolTip
	return
}

Reload_Func() {
	sleep 10
	Reload
	Sleep 10000
}

Exit_Func(ExitReason, ExitCode) {
	if ( ExitReason = "LogOff" ) || ( ExitReason = "ShutDown" ) || ( ExitReason = "Reload" ) || ( ExitReason = "Single" ) {
		Process, Close, nvcplui.exe
	}
	else {
		transArray := Get_Translation("Program_Exit", programLang)
        MsgBox, 4, % programName,% transArray[1]
        IfMsgBox, No
            return 1  ; OnExit functions must return non-zero to prevent exit.
		Process, Close, nvcplui.exe
    }
}

;==================================================================================================================
;
;																														TRAY MENU
;
;			Allows the user to open the settings/about menus.
;
;==================================================================================================================

Create_Tray_Menu(lang) {	
;			Create the tray menu n stuff
	handler := nvHandler
	transArray := Get_Translation("Tray_Menu", lang)
	Menu, Tray, DeleteAll
	Menu, Tray, Tip,% programName
	Menu, Tray, NoStandard
	Menu, Tray, Add,% transArray[1], Gui_Settings
	Menu, Tray, Add,% transArray[2], Gui_About
	Menu, Tray, Add, 
	Menu, Tray, Add,% transArray[3], Tray_Hide
	Menu, Tray, Check,% transArray[3]
	Menu, Tray, Add
	Menu, Tray, Add,% transArray[4], Tray_Reload
	Menu, Tray, Add,% transArray[5], Tray_Exit
	return

	Tray_Hide: 
		EN_Hide := "NVCPL Hidden", FR_Hide := "NVCPL Caché"
		if WinExist("ahk_exe nvcplui.exe") {
			if ( programLang = "EN" )
				Menu, Tray, Check,%EN_Hide%
			else if ( programLang = "FR" )
				Menu, Tray, Check,%FR_Hide%
			WinHide ahk_id %nvHandler%
		}
		else {
			if ( programLang = "EN" )
				Menu, Tray, UnCheck,%EN_Hide%
			else if ( programLang = "FR" )
				Menu, Tray, UnCheck,%FR_Hide%
			WinShow, ahk_id %nvHandler%
		}
	return
	
	Tray_Reload:
		Reload_Func()
	return
	
	Tray_Exit:
		ExitApp
	return
}

;==================================================================================================================
;
;																														UPDATE MENU
;
;			Notify the user upon finding a new update
;			Automatically download and run the new version if clicking Yes
;			Automatically download and run the new version if autoUpdate is enabled
;
;==================================================================================================================

Check_Update(auto) {
;			It works by downloading both the new version and the auto-updater
;			then closing the current instancie and renaming the new version
	static
	updaterPath := "gvUpdater.exe"
	beta := 0
	
	if ( beta ) {
		updaterDL := "https://raw.githubusercontent.com/lemasato/Beta-Stuff/master/Game-Vivifier/Updater.exe"
		versionDL := "https://raw.githubusercontent.com/lemasato/Beta-Stuff/master/Game-Vivifier/version.txt"
	}
	else {
		updaterDL := "https://raw.githubusercontent.com/lemasato/Game-Vivifier/master/Updater.exe"
		versionDL := "https://raw.githubusercontent.com/lemasato/Game-Vivifier/master/version.txt"
	}
	
;	Delete files remaining from updating
	if (FileExist(updaterPath))
		FileDelete,% updaterPath
	if (FileExist("Game Vivifier Updater.exe"))	; pre-2.0.6 updater name
		FileDelete,% "Game Vivifier Updater.exe"
	if (FileExist("gvNewver.exe"))
		FileDelete,% "gvNewver.exe"
	
;	Retrieve the version number
	ComObjError(0)
	whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	whr.Open("GET", versionDL, true)
	whr.Send()
	; Using 'true' above and the call below allows the script to remain responsive.
	whr.WaitForResponse(10) ; 10 seconds
	if ( whr.ResponseText <> "" ) && ( whr.ResponseText <> "NotFound" ) {
		newVersion := whr.ResponseText
		StringReplace, newVersion, newVersion, `n,,1 ; remove the 2nd line
	}
	else newVersion := programVersion ; couldn't reach the file, cancel update
	if ( programVersion <> newVersion )
		Gui_Update(auto, newVersion, updaterPath, updaterDL)
}

Gui_Update(auto, newVersion, updaterPath, updaterDL) {
	static
	if ( auto = 1 ) {
		GoSub Gui_Update_Accept
		return
	}
	Gui, Update:Destroy
	Gui, Update:New, +AlwaysOnTop +SysMenu -MinimizeBox -MaximizeBox +OwnDialogs +HwndUpdateGuiHwnd,% "Update! v" newVersion
	Gui, Update:Default
	Gui, Add, Text, x70 y10 hwndhandler1 w220,Would you like to update now?
	Gui, Add, Text, x10 y30 hwndhandler2 w280,The process is automatic, only your permission is required.
	Gui, Add, Button, x10 y55 w135 h35 gGui_Update_Accept hwndhandler3,Accept
	Gui, Add, Button, x145 y55 w135 h35 gGui_Update_Refuse hwndhandler4,Refuse
	Gui, Add, Button, x10 y95 w270 h40 gGui_Update_Open_Page hwndhandler5,Open the download page ; Open download page
	Gui, Add, CheckBox, x10 y150 w260 h30 vautoUpdate hwndhandler6,Update automatically from now ; Update automatically...
	
	handlersArray := []
	Loop  {
		item := handler%A_Index%
		if ( item <> "" )
			handlersArray.InsertAt(A_Index, item)
		else break
	}
	transArray := Get_Translation("Gui_Update", programLang)
	Set_Translation("Gui_Update", programLang, handlersArray, transArray)
	Gui, Show, AutoSize
	WinWait, ahk_id %UpdateGuiHwnd%
	WinWaitClose, ahk_id %UpdateGuiHwnd%
	return
	
	Gui_Update_Accept:
;		Downlaod the updater that will handle the updating process
		Gui, Submit
		if ( autoUpdate )
			IniWrite, 1,% iniFilePath,SETTINGS,AutoUpdate
		IniWrite,% A_ScriptName,% iniFilePath,SETTINGS,FileName
		UrlDownloadToFile,% updaterDL,% updaterPath
		sleep 1000
		Run, % updaterPath
		Process, close, %programPID%
		OnExit("Exit_Func", 0)
		ExitApp
	return
	
	Gui_Update_Refuse:
		Gui, Submit
		if ( autoUpdate )
			IniWrite, 1,% iniFilePath,SETTINGS,AutoUpdate
	return

	Gui_Update_Open_Page:
		Gui, Submit
		Run, % "https://autohotkey.com/boards/viewtopic.php?t=9455"
	return
}

;==================================================================================================================
;
;																														LANG SELECT MENU
;
;			Appears when the user hasn't set any language yet.
;			Returns the selected language.
;
;==================================================================================================================

Gui_LangSelect() {
	static
	if !(lang)
		lang := "EN"
	Gui, Lang:Destroy
	Gui, Lang:New, +AlwaysOnTop +SysMenu -MinimizeBox -MaximizeBox +OwnDialogs +LabelGui_LangSelect +hwndGuiLangHandler,% programName
	Gui, Lang:Default
	Gui, Add, Text, x10 y10 w140 hwndhandler1 ; Select a language:
	Gui, Add, Text, x10 y35 w300 hwndhandler2 ; Can be changed anytime from the [Settings] menu.
	Gui, Add, DropDownList, x165 y7 gGui_LangSelect_List_Event vlangListItem hwndhandler3 ; EN-FR
	GuiControl, Lang:Choose,%hwndhandler3%, 1
	Gui, Add, Button, x10 y70 w310 h30 gGui_LangSelect_Apply hwndhandler4 ; Apply
	
	handlersArray := []
	Loop  {
		item := handler%A_Index%
		if ( item <> "" )
			handlersArray.InsertAt(A_Index, item)
		else break
	}
	transArray := Get_Translation("Gui_Lang", lang)
	Set_Translation("Gui_Lang", lang, handlersArray, transArray)
	
	Gui, Show, AutoSize
	WinWait, ahk_id %GuiLangHandler%
	WinWaitClose, ahk_id %GuiLangHandler%
	return lang
	
	Gui_LangSelect_List_Event:
;		Instantly update the text language upon changing
		Gui, Submit, NoHide
		RegExMatch(langListItem, "(.*)-", lang)
		StringTrimRight, lang, lang, 1
		transArray := Get_Translation("Gui_Lang", lang)
		Set_Translation("Gui_Lang", lang, handlersArray, transArray)
	return
	
	Gui_LangSelect_Apply:
		Gui, Lang:Destroy
	return
	
	Gui_LangSelect_Close:
		Reload_Func()
	return
	
	Gui_LangSelect_Escape:
		Reload_Func()
	return
}

;==================================================================================================================
;
;																															GET CONTROL MENU
;
;			Appears when the control couldn't be automatically found
;			Ask the user to click on said control and returns it
;
;==================================================================================================================

Gui_Get_Control(ctrlName) {
;			Ask the user to click on a specific button so we can retrieve its control ID
	static
	global ctrlRetrieved, ctrlRetrievedText
	lang := programLang, handler := nvHandler
	
	Gui, GetControl:Destroy
	Gui, GetControl:New, +AlwaysOnTop +SysMenu -MinimizeBox -MaximizeBox +OwnDialogs +LabelGui_GetControl_ +hwndGuiNFRHwnd,% programName " - WARNING"
	Gui, GetControl:Default
	Gui, Add, text, x10 y10 h30 w350 hwndhandler1 ; Couldn't retrieve...
	Gui, Add, text, x10 y40 h30 w350 hwndhandler2 ; This error usually happens when...
	Gui, Add, text, x10 y60 h30 w350 hwndhandler3 ; Please, wait for the NVCPL...
	Gui, Add, text, x10 y90 w350 hwndhandler4 cBlue gGui_GetControl_Screenshot xs ; Click for screenshot...
	Gui, Add, text, x30 y130 w100 hwndhandler5 ; Ctrl retrieved:
	Gui, Add, Edit, x150 y127 w60 vctrlRetrieved WantReturn ReadOnly
	Gui, Add, text, x30 y160 w100 hwndhandler6 ; Ctrl expected:
	Gui, Add, Edit, x150 y157 w60 ReadOnly, Static2
	Gui, Add, text, x10 y190 w380 h30 cBlue gGui_About_Thread hwndhandler7 ; If you wish to help.... post on thread
	Gui, Add, Edit, x10 y225 w365 vctrlRetrievedText ReadOnly
	Gui, Add, Button, x240 y126 w120 h53 gGui_GetControl_Ok hwndhandler8 ; VALIDATE
	
	handlersArray := []
	Loop  {
		item := handler%A_Index%
		if ( item <> "" )
			handlersArray.InsertAt(A_Index, item)
		else break
	}	
	GoSub Gui_Settings_Refresh_Both_Lists
	Gui, Show, AutoSize
	transArray := Get_Translation("Gui_Get_Control", programLang, ctrlName)
	Set_Translation("Gui_Get_Control", programLang, handlersArray, transArray)
	Gui, Show, AutoSize
	WinShow, ahk_id %handler%
	WinRestore, ahk_id %handler%
	SetTimer, Gui_GetControl_Refresh, 100
	WinWait, ahk_id %GuiNFRHwnd%
	WinWaitClose, ahk_id %GuiNFRHwnd%
	WinHide, ahk_id %handler%
	return [ctrlRetrieved, ctrlRetrievedText]
	
	Gui_GetControl_Close:
		Reload_Func()
	return
	
	Gui_GetControl_Escape:
		Reload_Func()
	return

	Gui_GetControl_Screenshot:
		Run, % "https://raw.githubusercontent.com/lemasato/Game-Vivifier/master/Screenshots/Nvidia Control Panel.png"
	return
	
	Gui_GetControl_Ok:
		Gui, Submit, NoHide
		GuiControlGet, ctrlRetrieved
		if ctrlRetrieved contains Static
		{
			SetTimer, Gui_GetControl_Refresh, Off
			Gui, Submit
		}
	return
	
	Gui_GetControl_Refresh:
		MouseGetPos, , , winHandler
		WinGet, winEXE, ProcessName, ahk_id %winHandler%
		if ( winEXE = "nvcplui.exe" )
		{
			KeyWait, LButton, D
			MouseGetPos, , , , ctrlName
			ControlGetText, ctrlText,% ctrlName, ahk_id %winHandler%
			if ctrlName contains Static
			{
				GuiControl, GetControl:, ctrlRetrieved,% ctrlName
				GuiControl, GetControl:, ctrlRetrievedText,% ctrlText
			}
		}
	return 
}

;==================================================================================================================
;
;																															ABOUT MENU
;
;			Appears when clicking the "About" tray option.
;
;==================================================================================================================

Gui_About() {
	static	
	Gui, About:Destroy
	Gui, About:New, +HwndaboutGuiHandler +AlwaysOnTop +SysMenu -MinimizeBox -MaximizeBox +OwnDialogs,% programName " by masato - " programVersion
	Gui, About:Default
	Gui, Add, Text, x10 y10 w250 hwndhandler1 ; Hello, thank you for...
	Gui, Add, Text, x10 y35 w430 h50 hwndhandler2 ; It allows NVIDIA GPU owners to...
	Gui, Add, Text, x10 y75 w430 h50 hwndhandler3 ; If you would like to get started, ...
	Gui, Add, Link, x10 y130 w250 hwndhandler4
	Gui, Add, Link, x10 y145 w250 hwndhandler5
	;~ Gui, Add, Text, x10 y130 w250 cBlue gGui_About_Thread hwndhandler4 ; Click to visit...
	if !( FileExist( A_Temp "\gvpaypaldonatebutton.png" ) ) {
		UrlDownloadToFile, % "https://www.paypalobjects.com/en_US/i/btn/btn_donate_SM.gif", % A_Temp "\gvpaypaldonatebutton.png"
		if ( ErrorLevel )
			Gui, Add, Button, x350 y128 gGui_About_Donate hwnddonateHandler,Donations
	}
	Gui, Add, Picture, x350 y125 gGui_About_Donate hwnddonateHandler,% A_Temp "\gvpaypaldonatebutton.png"
	
	handlersArray := []
	Loop  {
		item := handler%A_Index%
		if ( item <> "" )
			handlersArray.InsertAt(A_Index, item)
		else break
	}	
	transArray := Get_Translation("Gui_About", programLang)
	Set_Translation("Gui_About", programLang, handlersArray, transArray)
	Gui, Show, AutoSize
	WinWait, ahk_id %aboutGuiHandler%
	WinWaitClose, ahk_id %aboutGuiHandler%
	return

	Gui_About_Donate:
		Run, % "https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=E9W692RF9ZLYA"
	return
}

;==================================================================================================================
;
;																															SETTINGS MENU
;
;			Appears when clicking on the "Settings" tray option.
;			Allows the user to set their custom profiles.
;
;==================================================================================================================

Gui_Settings:
	FR_helpMe_TT := "ID Écran: Changer cette value si les préférences ne sont pas appliquées sur le bon écran.`n`n"
		. "Liste de gauche" A_Tab . A_Tab "Programmes en cours.`n"
		. "Liste de droite" A_Tab . A_Tab "Programmes ajoutés à vos favoris.`n`n"
		. "Actualiser" A_Tab . A_Tab "Rafraîchit la liste des programmes en cours`n"
		. "->" A_Tab . A_Tab . A_Tab  "Ajoute le programme selectionné à vos favoris.`n"
		. "<-" A_Tab . A_Tab . A_Tab  "Supprime le favori selectionné.`n`n"
		. "Une fois qu'un programme a été ajouté à vos favoris,`n"
		. "sélectionnez-le et ajustez les curseurs à vos envies.`n"
		. "Les préférences sont sauvegardées instantanément."
		
	EN_helpMe_TT := "Monitor ID: Change this value if the preferences are not being set to the rigt monitor.`n`n"
		. "Left list" A_Tab . A_Tab "Currently running programs.`n"
		. "Right list" A_Tab A_Tab "Programs added to your favourites.`n`n"
		. "Refresh" A_Tab . A_Tab "Refresh the currently running programs list.`n"
		. "->" A_Tab . A_Tab "Add selected program to your favourites.`n"
		. "<-" A_Tab . A_Tab "Remove selected favourite from the list.`n`n"
		. "Once a program was added to your favourite,`n"
		. "select it and adjust the sliders to your will.`n"
		. "Preferences are instantly saved."
	;		Top Settings	
	Gui, Settings:Destroy
	Gui, Settings:New, +AlwaysOnTop +SysMenu -MinimizeBox -MaximizeBox +OwnDialogs +LabelGui_Settings_ hwndSettingsHandler,% programName " Settings"
	Gui, Settings:Default
	Gui, Add, CheckBox, x10 y10 w200 vrunOnStartup gGui_Settings_Apply hwndhandler1 ; Run On Startup box
	IniRead, runOnStartup,% iniFilePath,SETTINGS,RunOnStartup
	if ( runOnStartup )
		GuiControl, Settings:,runOnStartup,1
	Gui, Add, Text, x10 y35 w50 hwndhandler2 ; Language:
	Gui, Add, DropDownList, x70 y30 vlangListItem gGui_Settings_Langs_List_Event hwndhandler3 ; EN-FR
	;		Monitor ID
	IniRead, monID,% iniFilePath,SETTINGS,Monitor_ID
	Gui, Add, Text, x340 y30 w55 hwndhandler11,
	Gui, Add, Edit, xp+60 yp-3 w45 vMonitorID gGui_Settings_Apply,% monID
	Gui, Add, UpDown, Range0-100,% monID
	;		Left and Right boxes
	Gui, Add, ListBox, x10 y60 w250 h300 vleftListItem Sort
	Gui, Add, ListBox, x340 y60 w250 h300 vrightListItem gGui_Settings_Right_List_Event Sort
	;		Middle Buttons
	Gui, Add, Button, x260 y59 w80 h40 gGui_Settings_Detect_Hidden vdetectHidden hwndhandler4 ; Hidden Windows
	Gui, Add, Button, x260 y155 w80 h30 gGui_Settings_Right_Arrow,->
	Gui, Add, Button, x260 y185 w80 h40 gGui_Settings_Refresh_Both_Lists hwndhandler5 ; Refresh
	Gui, Add, Button, x260 y225 w80 h30 gGui_Settings_Left_Arrow,<-
	Gui, Add, Button, x260 y311 w80 h40 vhelpMe hwndhandler6 ; Help?
	;		Gamma Slider
	IniRead,gammaDefault,% iniFilePath,DEFAULT,Gamma
	Gui, Add, Text, x103 y359 w50 hwndhandler7 ; Gamma
	Gui, Add, Slider, x145 y355 w210 Range30-280 vgammaValue gGui_Settings_Slider_Event Line5 Page5 NoTicks AltSubmit, %gammaDefault%
	Gui, Add, Edit, x355 y355 w45 gGui_Settings_Slider_Event vgammaEdit, %gammaDefault%
	Gui, Add, UpDown, gGui_Settings_Slider_Event Range30-280, %gammaDefault%
	Gui, Add, Text, x410 y359 w35 hwndhandler8 ; Default
	Gui, Add, Edit, x453 y355 w45 vgammaDefault gGui_Settings_Slider_Event, %gammaDefault%
	Gui, Add, UpDown, Range-30-280 gGui_Settings_Slider_Event, %gammaDefault%
	;		Vibrance Slider
	IniRead,vibranceDefault,% iniFilePath,DEFAULT,Vibrance
	Gui, Add, Text, x103 y384 w50 hwndhandler9 ; Vibrance
	Gui, Add, Slider, x145 y380 w210 Range0-100 vvibranceValue gGui_Settings_Slider_Event Line5 Page5 NoTicks AltSubmit, %vibranceDefault%
	Gui, Add, Edit, x355 y380 w45 gGui_Settings_Slider_Event vvibranceEdit, %vibranceDefault%
	Gui, Add, UpDown, gGui_Settings_Slider_Event Range0-100, %vibranceDefault%
	Gui, Add, Text, x410 y384 w35 hwndhandler10 ; Default
	Gui, Add, Edit, x453 y380 w45 vvibranceDefault gGui_Settings_Slider_Event, %vibranceDefault%
	Gui, Add, UpDown, Range-0-100 gGui_Settings_Slider_Event, %vibranceDefault%

	handlersArray := []
	Loop  {
		item := handler%A_Index%
		if ( item <> "" )
			handlersArray.InsertAt(A_Index, item)
		else break
	}	
	GoSub Gui_Settings_Refresh_Both_Lists
	Gui, Show, AutoSize
	transArray := Get_Translation("Gui_Settings", programLang)
	Set_Translation("Gui_Settings", programLang, handlersArray, transArray)
	OnMessage(0x200,"WM_MOUSEMOVE", 1)
	guiSettingsCreated := 1
return


Gui_Settings_Langs_List_Event:
;			Triggers upon selecting another language
;			Redraws the menu with selected language aswell as the tray menu
		Gui, Submit, NoHide
		RegExMatch(langListItem, "(.*)-", lang)
		StringTrimRight, lang, lang, 1
		transArray := Get_Translation("Gui_Settings", lang)
		Set_Translation("Gui_Settings", lang, handlersArray, transArray)
		IniWrite,% lang,% iniFilePath,SETTINGS,Language
		programLang := lang
return

Gui_Settings_Right_List_Event:
;			Triggers upon selecting an item from the right list
;			Applies the correct values to the slider/editbox depending on the process
	Gui, Submit, NoHide
	IniRead, gammaValue,% iniFilePath,% rightListItem,Gamma
	IniRead, vibranceValue,% iniFilePath,% rightListItem,Vibrance
	IniRead, gammaDefault,% iniFilePath,DEFAULT,Gamma
	IniRead, vibranceDefault,% iniFilePath,DEFAULT,Vibrance
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


Gui_Settings_Slider_Event:
;			Make sure the slider and the editbox match the same value
	Gui, Submit, NoHide
	if ( rightListExe && guiSettingsCreated )
		GoSub Gui_Settings_Apply
;~ msgbox,% gammaValue "`n" vibranceValue "`n" winExe
return


Gui_Settings_Detect_Hidden:
;			Warning that opens upon ticking the box
	detectHidden := !detectHidden
	GoSub Gui_Settings_Refresh_Both_Lists
return


Gui_Settings_Right_Arrow:
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
	GoSub Gui_Settings_Refresh_Both_Lists
return


Gui_Settings_Left_Arrow:
;			Remove the item from the right list
;			Delete its entry name
	Gui, Submit, NoHide
	if ( rightListItem = "" )
		return
	IniDelete,% iniFilePath,% rightListItem
	GoSub Gui_Settings_Refresh_Both_Lists
return


Gui_Settings_Refresh_Both_Lists:
;			Refresh both lists
;			If the box was ticked, detect hidden windows too 
	Gui, Submit, NoHide
	if ( detectHidden )
		DetectHiddenWindows, On
	GoSub Gui_Settings_Refresh_Left_List
	GoSub Gui_Settings_Refresh_Right_List
	GoSub Gui_Settings_Right_List_Event
return


Gui_Settings_Refresh_Left_List:
;			Refresh the content from the left list
;			Retrieve all the current windows and put them into a list, sorted alphabetically
	WinGet, allWindows, List
	wList := "" ; Make sure to empty the list
	Loop, %allWindows% 
	{ 
		WinGetTitle, wTitle, % "ahk_id " allWindows%A_Index%
		WinGet, wExe, ProcessName, %wTitle%
		if wTitle contains |
			StringReplace wTitle, wTitle,|,I,1
		if ( wExe <> "explorer.exe" && wExe <> "autohotkey.exe" && wExe <> "nvcplui.exe" && wExe <> A_ScriptName && wExe <> "" ) ; Ignore these programs
			if wList not contains % wExe " // " wTitle "|"	; avoid duplicate
				wList .= wExe " // " wTitle "|"
	} 
	StringReplace, wList, wList,|,`n,1	; Replace list separators by a linefeed
	Sort, wList	; Sort the list alphabetically
	StringReplace, wList, wList,`n,|,1	; Put the list back in place
	GuiControl, Settings:,leftListItem,|%wList%
return


Gui_Settings_Refresh_Right_List:
;			Refresh the content of the right list
;			Retrieve all the sections from the ini file and put them into a list, sorted alphabetically
	rightListContent := "|"	; make sure to clear the content from the list
	IniRead, allSections,% iniFilePath	; retrieve all sections
	allSectionsArray := StrSplit(allSections, "`n")	; transform the linefeed into array
	for index, element in allSectionsArray ; for every section name
	{
		if ( element <> "GENERAL" && element <> "DEFAULT" && element <> "SETTINGS" ) { ; if the section is not part of those
			rightListContent .= element "|" ; add it in the list as a simple process
		}
	}
	StringReplace, rightListContent, rightListContent,|,`n,1	; Replace list separators by a linefeed
	Sort, rightListContent	; Sort the list alphabetically
	StringReplace, rightListContent, rightListContent,`n,|,1	; Put the list back in place
	GuiControl, Settings:,rightListItem,% rightListContent
return


Gui_Settings_Apply:
;			Create shortcut ir runOnStartup is ticked
;			Also perform numerous check before writting to the .ini
	Gui, Submit, NoHide
	if ( A_GuiControl = "gammaValue" ) {	; User moved the slider, adjust the edit
		gammaEdit := gammaValue
		GuiControl, Settings:,gammaEdit,%gammaEdit%
	}
	if ( A_GuiControl = "gammaEdit" ) {	; User moved the edit, adjust the slider
		gammaValue := gammaEdit
		GuiControl, Settings:,gammaValue,%gammaEdit%
	}
	if ( A_GuiControl = "vibranceValue" ) {
		vibranceEdit := vibranceValue
		GuiControl, Settings:,vibranceEdit,%vibranceValue%
	}
	if ( A_GuiControl = "vibranceEdit" ) {
		vibranceValue := vibranceEdit
		GuiControl, Settings:,vibranceValue,%vibranceEdit%
	}
	if ( rightListExe = "" ) {		; No item selected, gray out the controls
		GuiControl,Disable,gammaValue
		GuiControl,Disable,gammaEdit
		GuiControl,Disable,vibranceValue
		GuiControl,Disable,vibranceEdit
	}
	if ( rightListExe <> "" ) {	; item selected, enable controls and update the values from ini
		GuiControl,Enable,gammaValue
		GuiControl,Enable,gammaEdit
		GuiControl,Enable,vibranceValue
		GuiControl,Enable,vibranceEdit
		gammaValue := ( gammaValue > 280 ) ? ( 280 ) : ( gammaValue < 30 ) ? ( 30 ) : ( gammaValue )	; Prevent from setting outside min/max boundaries
		vibranceValue := ( vibranceValue > 100 ) ? ( 100 ) : ( vibranceValue < 0 ) ? ( 0 ) : ( vibranceValue )
		IniWrite,% gammaValue,% iniFilePath,% rightListExe,Gamma
		IniWrite,% vibranceValue,% iniFilePath,% rightListExe,Vibrance
	}
	if ( gammaDefault <> "" && gammaDefault <> "ERROR" ) {	; make sure the value is within boundaries
		gammaDefault := ( gammaDefault > 280 ) ? ( 280 ) : ( gammaDefault < 30 ) ? ( 30 ) : ( gammaDefault )	; Prevent from setting outside min/max boundaries
		IniWrite, % gammaDefault, % iniFilePath,DEFAULT,Gamma
	}
	if ( vibranceDefault <> "" && vibranceDefault <> "ERROR" ) {
		vibranceDefault := ( vibranceDefault > 100 ) ? ( 100 ) : ( vibranceDefault < 0 ) ? ( 0 ) : ( vibranceDefault )
		IniWrite, % vibranceDefault, % iniFilePath,DEFAULT,Vibrance
	}
	IniWrite, % runOnStartup, % iniFilePath,SETTINGS,RunOnStartup	
	IniWrite, % monitorID, % iniFilePath,SETTINGS,Monitor_ID	
	Update_Startup_Shortcut()
return


Gui_Settings_Close:
Gui, Settings:Destroy
guiSettingsCreated := 0
OnMessage(0x200,"WM_MOUSEMOVE", 0)
ToolTip,
return


Gui_Settings_Escape:
Gui, Settings:Destroy
guiSettingsCreated := 0
OnMessage(0x200,"WM_MOUSEMOVE", 0)
ToolTip,
return

;==================================================================================================================
;
;																															NvAPI Class by jNizM
;
;			Thread https://autohotkey.com/boards/viewtopic.php?f=6&t=5508
;			GitHub: https://github.com/jNizM/AHK_NVIDIA_NvAPI
;
;==================================================================================================================

class NvAPI
{
    static DllFile := (A_PtrSize = 8) ? "nvapi64.dll" : "nvapi.dll"
    static hmod
    static init := NvAPI.ClassInit()
    static DELFunc := OnExit(ObjBindMethod(NvAPI, "_Delete"))

    static NVAPI_GENERIC_STRING_MAX   := 4096
    static NVAPI_MAX_LOGICAL_GPUS     :=   64
    static NVAPI_MAX_PHYSICAL_GPUS    :=   64
    static NVAPI_MAX_VIO_DEVICES      :=    8
    static NVAPI_SHORT_STRING_MAX     :=   64

    static ErrorMessage := False

    ClassInit()
    {
        if !(NvAPI.hmod := DllCall("LoadLibrary", "Str", NvAPI.DllFile, "UPtr"))
        {
            MsgBox, 16, % A_ThisFunc, % "LoadLibrary Error: " A_LastEror
            ExitApp
        }
        if (NvStatus := DllCall(DllCall(NvAPI.DllFile "\nvapi_QueryInterface", "UInt", 0x0150E828, "CDECL UPtr"), "CDECL") != 0)
        {
            MsgBox, 16, % A_ThisFunc, % "NvAPI_Initialize Error: " NvStatus
            ExitApp
        }
    }
	
; ###############################################################################################################################

    EnumNvidiaDisplayHandle(thisEnum := 0)
    {
        static EnumNvidiaDisplayHandle := DllCall(NvAPI.DllFile "\nvapi_QueryInterface", "UInt", 0x9ABDD40D, "CDECL UPtr")
        if !(NvStatus := DllCall(EnumNvidiaDisplayHandle, "UInt", thisEnum, "UInt*", pNvDispHandle, "CDECL"))
            return pNvDispHandle
        return "*" NvStatus
    }

; ###############################################################################################################################

    GetAssociatedNvidiaDisplayHandle(thisEnum := 0)
    {
        static GetAssociatedNvidiaDisplayHandle := DllCall(NvAPI.DllFile "\nvapi_QueryInterface", "UInt", 0x35C29134, "CDECL UPtr")
        szDisplayName := NvAPI.GetAssociatedNvidiaDisplayName(thisEnum)
        if !(NvStatus := DllCall(GetAssociatedNvidiaDisplayHandle, "AStr", szDisplayName, "Int*", pNvDispHandle, "CDECL"))
            return pNvDispHandle
        return NvAPI.GetErrorMessage(NvStatus)
    }

; ###############################################################################################################################

    GetAssociatedNvidiaDisplayName(thisEnum := 0)
    {
        static GetAssociatedNvidiaDisplayName := DllCall(NvAPI.DllFile "\nvapi_QueryInterface", "UInt", 0x22A78B05, "CDECL UPtr")
        NvDispHandle := NvAPI.EnumNvidiaDisplayHandle(thisEnum)
        VarSetCapacity(szDisplayName, NvAPI.NVAPI_SHORT_STRING_MAX, 0)
        if !(NvStatus := DllCall(GetAssociatedNvidiaDisplayName, "Ptr", NvDispHandle, "Ptr", &szDisplayName, "CDECL"))
            return StrGet(&szDisplayName, "CP0")
        return NvAPI.GetErrorMessage(NvStatus)
    }

; ###############################################################################################################################

    GetDVCInfo(outputId := 0)
    {
        static GetDVCInfo := DllCall(NvAPI.DllFile "\nvapi_QueryInterface", "UInt", 0x4085DE45, "CDECL UPtr")
        static NV_DISPLAY_DVC_INFO := 16
        hNvDisplay := NvAPI.EnumNvidiaDisplayHandle()
        VarSetCapacity(pDVCInfo, NV_DISPLAY_DVC_INFO), NumPut(NV_DISPLAY_DVC_INFO | 0x10000, pDVCInfo, 0, "UInt")
        if !(NvStatus := DllCall(GetDVCInfo, "Ptr", hNvDisplay, "UInt", outputId, "Ptr", &pDVCInfo, "CDECL"))
        {
            DVC := {}
            DVC.version      := NumGet(pDVCInfo,  0, "UInt")
            DVC.currentLevel := NumGet(pDVCInfo,  4, "UInt")
            DVC.minLevel     := NumGet(pDVCInfo,  8, "UInt")
            DVC.maxLevel     := NumGet(pDVCInfo, 12, "UInt")
            return DVC
        }
        return NvAPI.GetErrorMessage(NvStatus)
    }

; ###############################################################################################################################

    GetDVCInfoEx(thisEnum := 0, outputId := 0)
    {
        static GetDVCInfoEx := DllCall(NvAPI.DllFile "\nvapi_QueryInterface", "UInt", 0x0E45002D, "CDECL UPtr")
        static NV_DISPLAY_DVC_INFO_EX := 20
        hNvDisplay := NvAPI.GetAssociatedNvidiaDisplayHandle(thisEnum)
        VarSetCapacity(pDVCInfo, NV_DISPLAY_DVC_INFO_EX), NumPut(NV_DISPLAY_DVC_INFO_EX | 0x10000, pDVCInfo, 0, "UInt")
        if !(NvStatus := DllCall(GetDVCInfoEx, "Ptr", hNvDisplay, "UInt", outputId, "Ptr", &pDVCInfo, "CDECL"))
        {
            DVC := {}
            DVC.version      := NumGet(pDVCInfo,  0, "UInt")
            DVC.currentLevel := NumGet(pDVCInfo,  4, "Int")
            DVC.minLevel     := NumGet(pDVCInfo,  8, "Int")
            DVC.maxLevel     := NumGet(pDVCInfo, 12, "Int")
            DVC.defaultLevel := NumGet(pDVCInfo, 16, "Int")
            return DVC
        }
        return NvAPI.GetErrorMessage(NvStatus)
    }

; ###############################################################################################################################

    GetErrorMessage(ErrorCode)
    {
        static GetErrorMessage := DllCall(NvAPI.DllFile "\nvapi_QueryInterface", "UInt", 0x6C2D048C, "CDECL UPtr")
        VarSetCapacity(szDesc, NvAPI.NVAPI_SHORT_STRING_MAX, 0)
        if !(NvStatus := DllCall(GetErrorMessage, "Ptr", ErrorCode, "WStr", szDesc, "CDECL"))
            return this.ErrorMessage ? "Error: " StrGet(&szDesc, "CP0") : "*" ErrorCode
        return NvStatus
    }

; ###############################################################################################################################

    SetDVCLevel(level, outputId := 0)
    {
        static SetDVCLevel := DllCall(NvAPI.DllFile "\nvapi_QueryInterface", "UInt", 0x172409B4, "CDECL UPtr")
        hNvDisplay := NvAPI.EnumNvidiaDisplayHandle()
        if !(NvStatus := DllCall(SetDVCLevel, "Ptr", hNvDisplay, "UInt", outputId, "UInt", level, "CDECL"))
            return level
        return NvAPI.GetErrorMessage(NvStatus)
    }

; ###############################################################################################################################

    SetDVCLevelEx(currentLevel, thisEnum := 0, outputId := 0)
    {
        static SetDVCLevelEx := DllCall(NvAPI.DllFile "\nvapi_QueryInterface", "UInt", 0x4A82C2B1, "CDECL UPtr")
        static NV_DISPLAY_DVC_INFO_EX := 20
        hNvDisplay := NvAPI.GetAssociatedNvidiaDisplayHandle(thisEnum)
        VarSetCapacity(pDVCInfo, NV_DISPLAY_DVC_INFO_EX)
        , NumPut(NvAPI.GetDVCInfoEx(thisEnum).version,      pDVCInfo,  0, "UInt")
        , NumPut(currentLevel,                              pDVCInfo,  4, "Int")
        , NumPut(NvAPI.GetDVCInfoEx(thisEnum).minLevel,     pDVCInfo,  8, "Int")
        , NumPut(NvAPI.GetDVCInfoEx(thisEnum).maxLevel,     pDVCInfo, 12, "Int")
        , NumPut(NvAPI.GetDVCInfoEx(thisEnum).defaultLevel, pDVCInfo, 16, "Int")
        return DllCall(SetDVCLevelEx, "Ptr", hNvDisplay, "UInt", outputId, "Ptr", &pDVCInfo, "CDECL")
    }

; ###############################################################################################################################

    _Delete()
    {
        DllCall(DllCall(NvAPI.DllFile "\nvapi_QueryInterface", "UInt", 0xD22BDD7E, "CDECL UPtr"), "CDECL")
        DllCall("FreeLibrary", "Ptr", NvAPI.hmod)
    }
}