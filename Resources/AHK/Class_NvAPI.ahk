;==================================================================================================================
;			NvAPI Class by jNizM
;
;			https://autohotkey.com/boards/viewtopic.php?f=6&t=5508
;			https://github.com/jNizM/AHK_NVIDIA_NvAPI
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