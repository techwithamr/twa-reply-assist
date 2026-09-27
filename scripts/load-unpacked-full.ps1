Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinApi5 {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@

function Get-UiaWindows {
  $root = [System.Windows.Automation.AutomationElement]::RootElement
  $winCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Window
  )
  $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)
}

function Find-WindowByName($pattern) {
  foreach ($w in Get-UiaWindows) {
    if ($w.Current.Name -match $pattern) { return $w }
  }
  return $null
}

$chrome = Find-WindowByName 'Extensions|إضافات'
if (-not $chrome) { throw "NO_EXTENSIONS_WINDOW" }

$btnCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Button
)
$load = $null
foreach ($b in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  if ($b.Current.AutomationId -eq 'loadUnpacked' -or $b.Current.Name -eq 'Load unpacked') { $load = $b; break }
}
if (-not $load) { throw "NO_LOAD_BUTTON" }
$load.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Write-Output "CLICKED_LOAD"

$dlg = $null
for ($i = 0; $i -lt 20; $i++) {
  Start-Sleep -Milliseconds 250
  foreach ($w in Get-UiaWindows) {
    $n = $w.Current.Name
    if ($n -match 'Select the extension|Select Folder|Open|فتح|اختيار') { $dlg = $w; Write-Output "DLG=$n"; break }
    if ($n -match 'File Explorer|مستكشف') { $dlg = $w; Write-Output "DLG=$n"; break }
  }
  if ($dlg) { break }
}
if (-not $dlg) {
  Write-Output "WINDOWS_NOW:"
  foreach ($w in Get-UiaWindows) { Write-Output "WIN=$($w.Current.Name)" }
  throw "NO_DIALOG"
}

[WinApi5]::SetForegroundWindow($dlg.Current.NativeWindowHandle) | Out-Null
Start-Sleep -Milliseconds 300
[System.Windows.Forms.SendKeys]::SendWait("%d")
Start-Sleep -Milliseconds 250
[System.Windows.Forms.SendKeys]::SendWait("C:\Github\twa-reply-assist")
Start-Sleep -Milliseconds 200
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Start-Sleep -Milliseconds 700

$select = $null
foreach ($b in $dlg.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  Write-Output "BTN=$($b.Current.Name)"
  if ($b.Current.Name -match 'Select Folder|Select extension|Select|اختيار المجلد') { $select = $b }
}
if ($select) {
  $select.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
  Write-Output "CLICKED_SELECT=$($select.Current.Name)"
} else {
  [System.Windows.Forms.SendKeys]::SendWait("%s")
  Start-Sleep -Milliseconds 200
  [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
  Write-Output "SENT_SELECT_KEYS"
}
