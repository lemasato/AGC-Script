/*		Credits: lemasato
		https://github.com/lemasato

		Allow creating GUIs in functions without having to declare the whole function as static
		Gui_Add(params): When a control has a variable attached to it, it's handle is added to a global associative array.
			Example: Gui_Add({_Name:"MyGui",_Type:"Text",_Content:"Sample text",_Var:"TEXT_Sample"})
					 will add the control's handle to an associative array called GuiMyGui_Controls.
					 The handle can be accessed by using its corresponding variable.Example: GuiMyGui_Controls["TEXT_Sample"]

		Gui_Submit(_arr,_Name,_Opts): Retrieve each control values and add them to a global associative array
			Example: Gui_Add(GuiMyGui_Controls, "MyGui")
					 will add the controls values to an associative array called GuiMyGui_Values.
					 The values can be accessed by using its corresponding variable. Example: GuiMyGui_Values["TEXT_Sample"]
*/

Gui_Control(_Name="",_Command="",_ControlID="",_Param3="") {
	GuiControl, %_Name%:%_Command%, %_ControlID%, %_Param3%
}

Gui_Submit(_arr,_Name,_Opts="") {
	Gui, %_Name%:Submit,% _Opts
	if (!Gui%_Name%_Submit) { ; Not exist, create it
		Gui%_Name%_Submit := {}
	}
	for ctrlName, ctrlHandler in _arr {
		GuiControlGet, content, %_Name%:,% _arr[ctrlName]
		Gui%_Name%_Submit[ctrlName] := content
	}
}

Gui_Add(params) {
	static
/*	Available params:
		_Name: 				GUI Name
		_Type:				Control Type
		_Content:			Content
		_Pos:				Position
		_Var:				Variable
		_Handler:			Handler
		_Label:				Label
		_Color				Font Color
		_Background			Background Color
		_Font:				Font
		_Font_Size			Font Size
		_Font_Quality		Font Quality
		_CB_State:			Checkbox state
		_Opts:				Additional params
*/
	availableParams := ["_Name","_Type","_Content","_Pos","_Var","_Handler","_Label","_Color","_Background","_Font","_Font_Size","_Font_Quality","_CB_State","_Choose","_Opts"]


;	Retrive the previous values, if these are not specified
	params._Name					:= (params._Name)?(params._Name):(prev_Name)
	params._Font 					:= (params._Font)?(params._Font):(prev_Font)
	params._Font_Size 				:= (params._Font_Size)?(params._Font_Size):(prev_Font_Size)
	params._Font_Quality 			:= (params._Font_Quality)?(params._Font_Quality):(prev_Font_Quality)
;	Associate an handler if variable exist but handler unspecified
	params._Handler := (params._Var && !params._Handler)?("h" params._Var):(params._Handler)
;	Retrieving the prefixes
	Gui_Prefixes(params)
	for id, variable in availableParams {
		%variable% := params[variable]
	}
	
	; Setting or defaulting the font
	fontHasParams := (_Font_Size || _Font_Quality)?(1):(0)
	if (!_Font && !fontHasParams) ; No font, no params
		Gui, %_Name%:Font
	else if (!_Font && fontHasParams) ; No font, params
		Gui, %_Name%:Font,%_Font_Size% %_Font_Quality%
	else ; has font and params
		Gui, %_Name%:Font,%_Font_Size% %_Font_Quality%,%_Font%

	; Adding the element
	Gui, %_Name%:Add, %_Type%, %_Pos% %_Var% %_Handler% %_Label% %_Color% %_Background% %_CB_State% %_Choose% %_Opts%,%_Content%

	if (_Handler) {
		if (!Gui%_Name%_Controls) { ; Not exist, create it
			Gui%_Name%_Controls := {}
		}
		local ctrlName, ctrlHandler
		StringTrimLeft, ctrlName, _Handler, 5
		StringTrimLeft, ctrlHandler, _Handler, 4
		ctrlHandler := %ctrlHandler%

		Gui%_Name%_Controls[ctrlName] := ctrlHandler
	}


	prev_Name 				:= _Name
	prev_Font 				:= _Font
	prev_Font_Size 			:= _Font_Size
	prev_Font_Quality 		:= _Font_Quality
	
}

Gui_Prefixes(ByRef arr) {
/*	Adds GUI prefixes to arr
*/
	arr._Var := (arr._Var)?("v" arr._Var):("")
	arr._Handler := (arr._Handler)?("hwnd" arr._Handler):("")
	arr._Label := (arr._Label)?("g" arr._Label):("")
	arr._Font_Size := (arr._Font_Size)?("S" arr._Font_Size):("")
	arr._Font_Quality := (arr._Font_Quality)?("Q" arr._Font_Quality):("")
	arr._Color := (arr._Color)?("C" arr._Color):("")
	arr._Background := (arr._Background)?("Background" arr._Background):("")
	arr._CB_State := (arr._CB_State)?("Checked" arr._CB_State):("")
	arr._Choose := (arr._Choose)?("Choose" arr._Choose):("")
}