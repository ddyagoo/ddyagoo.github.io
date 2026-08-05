[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Install', 'Uninstall')]
    [string]$Action
)

$ErrorActionPreference = 'Stop'

$taskPath = '\WindowsThemeSwitch\'
$folderName = $taskPath.Trim('\')
$taskNames = @(
    'StartupTimeCheck',
    'MorningLight_0800',
    'NightDark_2300'
)
$scriptDirectory = $PSScriptRoot
$themeScriptPath = Join-Path -Path $scriptDirectory -ChildPath 'windows-theme.ps1'
$launcherPath = Join-Path -Path $scriptDirectory -ChildPath 'run-windows-theme-hidden.vbs'
$systemWScript = Join-Path -Path $env:SystemRoot -ChildPath 'System32\wscript.exe'
$wscriptExe = if (Test-Path -LiteralPath $systemWScript) { $systemWScript } else { 'wscript.exe' }
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

function Get-TaskSchedulerService {
    $service = New-Object -ComObject 'Schedule.Service'
    $service.Connect()
    return $service
}

function Ensure-TaskFolder {
    param([object]$Service)

    $root = $Service.GetFolder('\')
    try {
        return $root.GetFolder($taskPath.TrimEnd('\'))
    }
    catch {
        [void]$root.CreateFolder($folderName, $null)
        return $root.GetFolder($taskPath.TrimEnd('\'))
    }
}

function Unregister-ThemeTask {
    param([string]$Name)

    $existing = Get-ScheduledTask -TaskPath $taskPath -TaskName $Name -ErrorAction SilentlyContinue
    if ($null -ne $existing) {
        Unregister-ScheduledTask -TaskPath $taskPath -TaskName $Name -Confirm:$false
        Write-Output ("Removed existing task: {0}{1}" -f $taskPath, $Name)
    }
}

try {
    $service = Get-TaskSchedulerService
    $root = $service.GetFolder('\')

    if ($Action -eq 'Uninstall') {
        try {
            [void]$root.GetFolder($taskPath.TrimEnd('\'))
        }
        catch {
            Write-Output ("Task folder does not exist: {0}" -f $taskPath)
            exit 0
        }

        foreach ($taskName in $taskNames) {
            Unregister-ThemeTask -Name $taskName
        }

        $folder = $root.GetFolder($taskPath.TrimEnd('\'))
        if ($folder.GetTasks(0).Count -eq 0) {
            [void]$root.DeleteFolder($folderName, 0)
            Write-Output ("Removed empty task folder: {0}" -f $taskPath)
        } else {
            Write-Output ("Kept task folder because it contains other tasks: {0}" -f $taskPath)
        }

        exit 0
    }

    if (-not (Test-Path -LiteralPath $themeScriptPath)) {
        throw ("Theme worker was not found: {0}" -f $themeScriptPath)
    }
    if (-not (Test-Path -LiteralPath $launcherPath)) {
        throw ("Hidden launcher was not found: {0}" -f $launcherPath)
    }

    [void](Ensure-TaskFolder -Service $service)

    $actionArguments = '"{0}" auto' -f $launcherPath
    $taskAction = New-ScheduledTaskAction -Execute $wscriptExe -Argument $actionArguments
    $taskSettings = New-ScheduledTaskSettingsSet `
        -StartWhenAvailable `
        -MultipleInstances IgnoreNew `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
    $taskPrincipal = New-ScheduledTaskPrincipal `
        -UserId $currentUser `
        -LogonType Interactive `
        -RunLevel Limited

    $today = (Get-Date).Date
    $startupTrigger = New-ScheduledTaskTrigger -AtLogOn -User $currentUser
    # 修改这里的 8 可以调整浅色任务的触发时间，按 24 小时制填写，例如 9 表示 09:00。
    $morningTrigger = New-ScheduledTaskTrigger -Daily -At $today.AddHours(8)
    # 修改这里的 23 可以调整深色任务的触发时间，按 24 小时制填写，例如 22 表示 22:00。
    $nightTrigger = New-ScheduledTaskTrigger -Daily -At $today.AddHours(23)

    $definitions = @(
        [pscustomobject]@{
            Name = 'StartupTimeCheck'
            Trigger = $startupTrigger
            Description = 'Apply the correct Windows mode for the current user after logon.'
        },
        [pscustomobject]@{
            Name = 'MorningLight_0800'
            Trigger = $morningTrigger
            Description = 'Apply the correct Windows mode at 08:00 local time.'
        },
        [pscustomobject]@{
            Name = 'NightDark_2300'
            Trigger = $nightTrigger
            Description = 'Apply the correct Windows mode at 23:00 local time.'
        }
    )

    foreach ($definition in $definitions) {
        Unregister-ThemeTask -Name $definition.Name
        Register-ScheduledTask `
            -TaskName $definition.Name `
            -TaskPath $taskPath `
            -Action $taskAction `
            -Trigger $definition.Trigger `
            -Settings $taskSettings `
            -Principal $taskPrincipal `
            -Description $definition.Description `
            -Force | Out-Null
        Write-Output ("Registered task: {0}{1}" -f $taskPath, $definition.Name)
    }

    $applyProcess = Start-Process `
        -FilePath $wscriptExe `
        -ArgumentList $actionArguments `
        -Wait `
        -PassThru `
        -WindowStyle Hidden
    if ($applyProcess.ExitCode -ne 0) {
        throw ("The tasks were registered, but applying the current theme failed with exit code {0}." -f $applyProcess.ExitCode)
    }

    Write-Output ("Installed tasks for current user: {0}" -f $currentUser)
    Write-Output ("Task folder: {0}" -f $taskPath)
}
catch {
    Write-Error $_
    exit 1
}
