Option Explicit

Dim shell
Dim fileSystem
Dim scriptDirectory
Dim powerShellPath
Dim themeScriptPath
Dim mode
Dim command
Dim exitCode

Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

scriptDirectory = fileSystem.GetParentFolderName(WScript.ScriptFullName)
powerShellPath = shell.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"
If Not fileSystem.FileExists(powerShellPath) Then
    powerShellPath = "powershell.exe"
End If

themeScriptPath = fileSystem.BuildPath(scriptDirectory, "windows-theme.ps1")
mode = "auto"
If WScript.Arguments.Count > 0 Then
    mode = WScript.Arguments(0)
End If

command = Quote(powerShellPath) & " -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File " & Quote(themeScriptPath) & " -Mode " & Quote(mode)
exitCode = shell.Run(command, 0, True)
WScript.Quit exitCode

Function Quote(value)
    Quote = Chr(34) & Replace(value, Chr(34), Chr(34) & Chr(34)) & Chr(34)
End Function
