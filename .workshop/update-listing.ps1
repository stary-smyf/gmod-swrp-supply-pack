param(
    [string[]]$ScreenshotPaths = @(),
    [switch]$MakePublic,
    [switch]$SkipDependency
)
$ErrorActionPreference = 'Stop'
$env:SteamAppId = '4000'
$nativeSource = @'
using System;
using System.Runtime.InteropServices;
public static class SupplyPackSteamWorkshop {
    const string Dll = @"D:\SteamGames\steamapps\common\GarrysMod\bin\win64\steam_api64.dll";
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)]
    [return: MarshalAs(UnmanagedType.I1)] public static extern bool SteamAPI_Init();
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] public static extern void SteamAPI_Shutdown();
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] public static extern void SteamAPI_RunCallbacks();
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] public static extern IntPtr SteamAPI_SteamUGC_v021();
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] public static extern IntPtr SteamAPI_SteamUtils_v010();
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] public static extern ulong SteamAPI_ISteamUGC_StartItemUpdate(IntPtr self, uint app, ulong item);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)]
    [return: MarshalAs(UnmanagedType.I1)] public static extern bool SteamAPI_ISteamUGC_SetItemDescription(IntPtr self, ulong update, [MarshalAs(UnmanagedType.LPUTF8Str)] string text);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)]
    [return: MarshalAs(UnmanagedType.I1)] public static extern bool SteamAPI_ISteamUGC_SetItemVisibility(IntPtr self, ulong update, int visibility);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)]
    [return: MarshalAs(UnmanagedType.I1)] public static extern bool SteamAPI_ISteamUGC_AddItemPreviewFile(IntPtr self, ulong update, [MarshalAs(UnmanagedType.LPUTF8Str)] string path, int type);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] public static extern ulong SteamAPI_ISteamUGC_SubmitItemUpdate(IntPtr self, ulong update, [MarshalAs(UnmanagedType.LPUTF8Str)] string notes);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)] public static extern ulong SteamAPI_ISteamUGC_AddDependency(IntPtr self, ulong item, ulong dependency);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)]
    [return: MarshalAs(UnmanagedType.I1)] public static extern bool SteamAPI_ISteamUtils_IsAPICallCompleted(IntPtr self, ulong call, [MarshalAs(UnmanagedType.I1)] out bool failed);
    [DllImport(Dll, CallingConvention=CallingConvention.Cdecl)]
    [return: MarshalAs(UnmanagedType.I1)] public static extern bool SteamAPI_ISteamUtils_GetAPICallResult(IntPtr self, ulong call, IntPtr buffer, int size, int callback, [MarshalAs(UnmanagedType.I1)] out bool failed);
}
'@
Add-Type -TypeDefinition $nativeSource
if (-not [SupplyPackSteamWorkshop]::SteamAPI_Init()) { throw 'Cannot connect to the signed-in Steam client.' }
function Wait-WorkshopCall([ulong]$Call, [int]$Callback, [int]$Size) {
    if ($Call -eq 0) { throw 'Steam returned an invalid API call.' }
    $utils = [SupplyPackSteamWorkshop]::SteamAPI_SteamUtils_v010()
    $deadline = [DateTime]::UtcNow.AddSeconds(90)
    $failed = $false
    while (-not [SupplyPackSteamWorkshop]::SteamAPI_ISteamUtils_IsAPICallCompleted($utils, $Call, [ref]$failed)) {
        if ([DateTime]::UtcNow -gt $deadline) { throw 'Steam Workshop request timed out.' }
        [SupplyPackSteamWorkshop]::SteamAPI_RunCallbacks()
        Start-Sleep -Milliseconds 100
    }
    if ($failed) { throw 'Steam Workshop request failed during transport.' }
    $buffer = [Runtime.InteropServices.Marshal]::AllocHGlobal($Size)
    try {
        if (-not [SupplyPackSteamWorkshop]::SteamAPI_ISteamUtils_GetAPICallResult($utils, $Call, $buffer, $Size, $Callback, [ref]$failed) -or $failed) {
            throw 'Unable to read the Steam Workshop result.'
        }
        $result = [Runtime.InteropServices.Marshal]::ReadInt32($buffer)
        if ($result -ne 1) { throw "Steam Workshop returned EResult $result." }
        if ($Callback -eq 3404 -and [Runtime.InteropServices.Marshal]::ReadByte($buffer, 4) -ne 0) {
            throw 'The account owner must accept the Steam Workshop legal agreement on Steam.'
        }
        Write-Output "Steam Workshop operation succeeded (callback $Callback)."
    } finally {
        [Runtime.InteropServices.Marshal]::FreeHGlobal($buffer)
    }
}
try {
    $ugc = [SupplyPackSteamWorkshop]::SteamAPI_SteamUGC_v021()
    if ($ugc -eq [IntPtr]::Zero) { throw 'Steam UGC interface unavailable.' }
    if (-not $SkipDependency) {
        $dependencyCall = [SupplyPackSteamWorkshop]::SteamAPI_ISteamUGC_AddDependency($ugc, 3822344108, 2813179606)
        Wait-WorkshopCall $dependencyCall 3412 24
    }
    $update = [SupplyPackSteamWorkshop]::SteamAPI_ISteamUGC_StartItemUpdate($ugc, 4000, 3822344108)
    $description = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'description.txt'))
    if (-not [SupplyPackSteamWorkshop]::SteamAPI_ISteamUGC_SetItemDescription($ugc, $update, $description)) { throw 'Description rejected.' }
    foreach ($screenshot in $ScreenshotPaths) {
        $fullPath = (Resolve-Path -LiteralPath $screenshot).Path
        if (-not [SupplyPackSteamWorkshop]::SteamAPI_ISteamUGC_AddItemPreviewFile($ugc, $update, $fullPath, 0)) { throw "Screenshot rejected: $fullPath" }
    }
    if ($MakePublic -and -not [SupplyPackSteamWorkshop]::SteamAPI_ISteamUGC_SetItemVisibility($ugc, $update, 0)) { throw 'Public visibility rejected.' }
    $updateCall = [SupplyPackSteamWorkshop]::SteamAPI_ISteamUGC_SubmitItemUpdate($ugc, $update, 'Add description, model credit and required content.')
    Wait-WorkshopCall $updateCall 3404 16
    Write-Output 'Workshop item: https://steamcommunity.com/sharedfiles/filedetails/?id=3822344108'
} finally {
    [SupplyPackSteamWorkshop]::SteamAPI_Shutdown()
}
