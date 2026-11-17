Option Explicit
Dim shell, fso, folder, psFile, args
Set shell = CreateObject("Shell.Application")
Set fso = CreateObject("Scripting.FileSystemObject")
folder = fso.GetParentFolderName(WScript.ScriptFullName)
psFile = fso.BuildPath(folder, "Universal-SSL-Manager.ps1")
If Not fso.FileExists(psFile) Then
    MsgBox "Cannot find Universal-SSL-Manager.ps1 in:" & vbCrLf & folder, vbCritical, "Universal SSL Manager"
    WScript.Quit 1
End If
args = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " & Chr(34) & psFile & Chr(34)
On Error Resume Next
shell.ShellExecute "powershell.exe", args, folder, "runas", 0
If Err.Number <> 0 Then
    MsgBox "Could not start SSL Manager: " & Err.Description, vbExclamation, "Universal SSL Manager"
End If
