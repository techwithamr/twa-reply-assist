Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinApi6 {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
}
"@

function Get-TopWindows {
  $root = [System.Windows.Automation.AutomationElement]::RootElement
  $winCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Window
  )
  $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)
}

$chrome = $null
foreach ($w in Get-TopWindows) {
  if ($w.Current.Name -match 'Extensions|إضافات') { $chrome = $w }
}
if (-not $chrome) { throw "NO_EXTENSIONS_WINDOW" }
Write-Output "WIN=$($chrome.Current.Name)"

$editCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Edit
)
foreach ($e in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)) {
  Write-Output "EDIT name='$($e.Current.Name)' id='$($e.Current.AutomationId)'"
  if ($e.Current.Name -match 'Search' -or $e.Current.AutomationId -match 'search') {
    $e.SetFocus()
    $val = $e.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
    $val.SetValue("")
    Write-Output "CLEARED_SEARCH"
  }
}

# Child windows inside Chrome (modal picker)
$childWins = $chrome.FindAll([System.Windows.Automation.TreeScope]::Children, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Window)))
Write-Output "CHILD_WINS=$($childWins.Count)"
foreach ($c in $childWins) { Write-Output "CHILD=$($c.Current.Name)" }

$btnCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Button
)
$before = @{}
foreach ($w in Get-TopWindows) { $before[$w.Current.NativeWindowHandle.ToString()] = $w.Current.Name }

$load = $null
foreach ($b in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  if ($b.Current.AutomationId -eq 'loadUnpacked') { $load = $b; break }
}
if (-not $load) { throw "NO_LOAD" }
. (Join-Path $PSScriptRoot "_repo-root.ps1")
Set-Clipboard -Value $script:TwaRepoRoot
[WinApi6]::SetForegroundWindow($chrome.Current.NativeWindowHandle) | Out-Null
Start-Sleep -Milliseconds 200
$load.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Write-Output "CLICKED_LOAD"

$newWin = $null
for ($i = 0; $i -lt 24; $i++) {
  Start-Sleep -Milliseconds 250
  foreach ($w in Get-TopWindows) {
    $h = $w.Current.NativeWindowHandle.ToString()
    $n = $w.Current.Name
    if (-not $before.ContainsKey($h) -and $n -notmatch 'Cursor|NVIDIA|Overlay') {
      $newWin = $w
      Write-Output "NEW_WIN=$n handle=$h"
      break
    }
  }
  $childWins = $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Window)))
  if ($childWins.Count -gt 0) {
    foreach ($c in $childWins) { Write-Output "AFTER_CHILD=$($c.Current.Name)" }
  }
  if ($newWin) { break }
}

if (-not $newWin) {
  Write-Output "NO_NEW_WINDOW"
  foreach ($w in Get-TopWindows) { Write-Output "WIN=$($w.Current.Name)" }
  exit 2
}

[WinApi6]::SetForegroundWindow($newWin.Current.NativeWindowHandle) | Out-Null
Start-Sleep -Milliseconds 300
[System.Windows.Forms.SendKeys]::SendWait("%d")
Start-Sleep -Milliseconds 250
[System.Windows.Forms.SendKeys]::SendWait("^a")
Start-Sleep -Milliseconds 100
[System.Windows.Forms.SendKeys]::SendWait("^v")
Start-Sleep -Milliseconds 200
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Start-Sleep -Milliseconds 800
[System.Windows.Forms.SendKeys]::SendWait("%s")
Start-Sleep -Milliseconds 200
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Write-Output "FOLDER_KEYS_SENT"
