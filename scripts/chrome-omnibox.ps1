Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinApi3 {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

$root = [System.Windows.Automation.AutomationElement]::RootElement
$winCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Window
)
$chrome = $null
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
  if ($w.Current.Name -match 'Chrome|كروم') { $chrome = $w; Write-Output "WIN=$($w.Current.Name)" }
}
if (-not $chrome) { throw "NO_CHROME" }

$editCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Edit
)
$edits = $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)
Write-Output "EDIT_COUNT=$($edits.Count)"
foreach ($e in $edits) {
  Write-Output "EDIT name='$($e.Current.Name)' id='$($e.Current.AutomationId)'"
}

$box = $null
foreach ($e in $edits) {
  if ($e.Current.Name -match 'Address|search|عنوان|بحث|Omnibox') { $box = $e; break }
}
if (-not $box -and $edits.Count -gt 0) { $box = $edits[0] }
if (-not $box) { throw "NO_OMNIBOX" }

Write-Output "USING=$($box.Current.Name)"
$val = $box.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
$val.SetValue("chrome://extensions")
[WinApi3]::ShowWindow($chrome.Current.NativeWindowHandle, 9) | Out-Null
[WinApi3]::SetForegroundWindow($chrome.Current.NativeWindowHandle) | Out-Null
$box.SetFocus()
Start-Sleep -Milliseconds 200
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Write-Output "OMNIBOX_SET"
