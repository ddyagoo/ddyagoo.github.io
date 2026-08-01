[CmdletBinding()]
param(
    [ValidateSet('light', 'dark', 'auto')]
    [string]$Mode = 'auto'
)

$ErrorActionPreference = 'Stop'

$requestedMode = $Mode.ToLowerInvariant()
$now = Get-Date

if ($requestedMode -eq 'auto') {
    $minutes = ($now.Hour * 60) + $now.Minute
    if ($minutes -ge (7 * 60) -and $minutes -lt (23 * 60)) {
        $effectiveMode = 'light'
    } else {
        $effectiveMode = 'dark'
    }
} else {
    $effectiveMode = $requestedMode
}

$lightValue = if ($effectiveMode -eq 'light') { 1 } else { 0 }
$personalizeKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'

if (-not (Test-Path -LiteralPath $personalizeKey)) {
    New-Item -Path $personalizeKey -Force | Out-Null
}

New-ItemProperty -LiteralPath $personalizeKey -Name 'AppsUseLightTheme' -PropertyType DWord -Value $lightValue -Force | Out-Null
New-ItemProperty -LiteralPath $personalizeKey -Name 'SystemUsesLightTheme' -PropertyType DWord -Value $lightValue -Force | Out-Null

# Notify the current desktop and applications, then ask Windows to refresh per-user settings.
if (-not ([System.Management.Automation.PSTypeName]'ThemeRefreshNative').Type) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class ThemeRefreshNative
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd,
        uint msg,
        UIntPtr wParam,
        IntPtr lParam,
        uint flags,
        uint timeout,
        out UIntPtr result);
}
'@
}

$parameterPointer = [IntPtr]::Zero
try {
    $parameterPointer = [Runtime.InteropServices.Marshal]::StringToHGlobalUni('ImmersiveColorSet')
    $result = [UIntPtr]::Zero
    [void][ThemeRefreshNative]::SendMessageTimeout(
        [IntPtr](-1),
        [uint32]0x001A,
        [UIntPtr]::Zero,
        $parameterPointer,
        [uint32]0x0002,
        [uint32]1000,
        [ref]$result)
}
finally {
    if ($parameterPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::FreeHGlobal($parameterPointer)
    }
}

$refreshDll = Join-Path -Path $env:SystemRoot -ChildPath 'System32\rundll32.exe'
if (Test-Path -LiteralPath $refreshDll) {
    & $refreshDll 'user32.dll,UpdatePerUserSystemParameters' | Out-Null
}

Write-Output ("Applied {0} Windows mode for the current user at {1}." -f $effectiveMode, $now.ToString('HH:mm'))
