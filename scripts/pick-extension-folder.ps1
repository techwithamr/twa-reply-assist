Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinApi4 {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@

$root = [System.Windows.Automation.AutomationElement]::RootElement
$winCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Window
)
$dlg = $null
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
  $n = $w.Current.Name
  Write-Output "WIN=$n"
  if ($n -match 'Select|Folder|Browse|اختيار|مجلد|Open|فتح') { $dlg = $w }
}
if (-not $dlg) { throw "NO_FOLDER_DIALOG" }

Write-Output "DLG=$($dlg.Current.Name)"
[WinApi4]::SetForegroundWindow($dlg.Current.NativeWindowHandle) | Out-Null
Start-Sleep -Milliseconds 250

# Prefer the folder dialog address bar / filename edit
$editCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Edit
)
$edits = $dlg.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)
Write-Output "EDIT_COUNT=$($edits.Count)"
foreach ($e in $edits) { Write-Output "EDIT name='$($e.Current.Name)' id='$($e.Current.AutomationId)'" }

. (Join-Path $PSScriptRoot "_repo-root.ps1")
$path = $script:TwaRepoRoot
$targetEdit = $null
foreach ($e in $edits) {
  if ($e.Current.Name -match 'Folder|File name|اسم|Address|عنوان') { $targetEdit = $e; break }
}
if (-not $targetEdit -and $edits.Count -gt 0) { $targetEdit = $edits[$edits.Count - 1] }
if ($targetEdit) {
  $targetEdit.SetFocus()
  $val = $targetEdit.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
  $val.SetValue($path)
  Write-Output "SET_EDIT=$($targetEdit.Current.Name)"
} else {
  [System.Windows.Forms.SendKeys]::SendWait($path)
  Write-Output "TYPED_PATH"
}

Start-Sleep -Milliseconds 200
$btnCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Button
)
$btns = $dlg.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
foreach ($b in $btns) { Write-Output "BTN name='$($b.Current.Name)'" }
$select = $null
foreach ($b in $btns) {
  if ($b.Current.Name -match 'Select Folder|Select|اختيار المجلد|فتح|Open') { $select = $b; break }
}
if ($select) {
  $select.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
  Write-Output "CLICKED=$($select.Current.Name)"
} else {
  [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
  Write-Output "ENTER"
}
