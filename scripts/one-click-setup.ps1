param(
  [string]$ReleaseDir = ""
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class TwaSetupUi {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[TwaSetupUi]::SetProcessDPIAware() | Out-Null

$here = if ($ReleaseDir) { (Resolve-Path -LiteralPath $ReleaseDir).Path } else { $PSScriptRoot }
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (-not $ReleaseDir) {
  $candidate = Join-Path $repoRoot "release"
  if (Test-Path -LiteralPath $candidate) { $here = $candidate }
}

$installRoot = "C:\Github\twa-reply-assist"
$chromeZip = Get-ChildItem -LiteralPath $here -Filter "twa-reply-assist-chrome-*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $chromeZip) {
  throw "NO_CHROME_ZIP in $here — run: node scripts/package-release.mjs"
}

Write-Output "ZIP=$($chromeZip.FullName)"
New-Item -ItemType Directory -Force -Path $installRoot | Out-Null
$temp = Join-Path $env:TEMP ("twa-setup-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $temp | Out-Null
Expand-Archive -LiteralPath $chromeZip.FullName -DestinationPath $temp -Force
Get-ChildItem -LiteralPath $temp -Force | ForEach-Object {
  Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $installRoot $_.Name) -Recurse -Force
}
if (-not (Test-Path -LiteralPath (Join-Path $installRoot "manifest.json"))) {
  throw "EXTRACT_FAILED no manifest.json in $installRoot"
}
Write-Output "INSTALLED=$installRoot"

$chromeExe = @(
  "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
  "C:\Program Files\Google\Chrome\Application\chrome.exe",
  "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $chromeExe) { throw "NO_CHROME_EXE" }

Start-Process -FilePath $chromeExe -ArgumentList "chrome://extensions"
Start-Sleep -Seconds 2

function Get-ChromeWindow {
  $root = [System.Windows.Automation.AutomationElement]::RootElement
  $winCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Window
  )
  foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
    if ($w.Current.Name -match 'Google Chrome' -and $w.Current.Name -notmatch 'Remote Desktop') { return $w }
  }
  return $null
}

$chrome = $null
for ($i = 0; $i -lt 20; $i++) {
  $chrome = Get-ChromeWindow
  if ($chrome) { break }
  Start-Sleep -Milliseconds 250
}
if (-not $chrome) { throw "NO_CHROME_WINDOW" }

$hwnd = [IntPtr]$chrome.Current.NativeWindowHandle
[TwaSetupUi]::ShowWindow($hwnd, 3) | Out-Null
[TwaSetupUi]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 400

# Ensure extensions page
$editCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Edit
)
$omnibox = $null
foreach ($e in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)) {
  if ($e.Current.Name -eq 'Address and search bar') { $omnibox = $e; break }
}
if ($omnibox) {
  $omnibox.SetFocus()
  $omnibox.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue("chrome://extensions")
  [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
  Start-Sleep -Seconds 2
  $chrome = Get-ChromeWindow
}

$btnCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Button
)
$chkCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::CheckBox
)

# Developer mode
foreach ($c in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $chkCond)) {
  if ($c.Current.Name -match 'Developer mode|وضع المطو') {
    try {
      $tp = $c.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
      if ($tp.Current.ToggleState -ne [System.Windows.Automation.ToggleState]::On) { $tp.Toggle() }
      Write-Output "DEV_MODE_ON"
    } catch { Write-Output "DEV_MODE_SKIP" }
    break
  }
}
Start-Sleep -Milliseconds 600
$chrome = Get-ChromeWindow

$load = $null
foreach ($b in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  if ($b.Current.AutomationId -eq 'loadUnpacked' -or $b.Current.Name -match 'Load unpacked|تحميل') {
    $load = $b
    break
  }
}
if (-not $load) {
  Write-Output "MANUAL_LOAD folder=$installRoot"
  Set-Clipboard -Value $installRoot
  Write-Output "FOLDER_COPIED_TO_CLIPBOARD"
  exit 0
}

$load.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Write-Output "CLICKED_LOAD"

$winCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Window
)
$dlg = $null
for ($i = 0; $i -lt 30; $i++) {
  Start-Sleep -Milliseconds 200
  $chrome = Get-ChromeWindow
  foreach ($w in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $winCond)) {
    if ($w.Current.Name -eq 'Select the extension directory.') { $dlg = $w; break }
  }
  if (-not $dlg) {
    foreach ($w in [System.Windows.Automation.AutomationElement]::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
      if ($w.Current.Name -match 'Select the extension|Select Folder') { $dlg = $w; break }
    }
  }
  if ($dlg) { break }
}
if (-not $dlg) {
  Set-Clipboard -Value $installRoot
  Write-Output "NO_DIALOG folder_on_clipboard=$installRoot"
  exit 0
}

$folderEdit = $null
foreach ($e in $dlg.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)) {
  if ($e.Current.Name -eq 'Folder:' -or $e.Current.AutomationId -eq '1152') { $folderEdit = $e }
}
if ($folderEdit) {
  $folderEdit.SetFocus()
  $folderEdit.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue($installRoot)
  Write-Output "FOLDER_SET"
} else {
  [TwaSetupUi]::SetForegroundWindow([IntPtr]$dlg.Current.NativeWindowHandle) | Out-Null
  [System.Windows.Forms.SendKeys]::SendWait("%d")
  Start-Sleep -Milliseconds 200
  [System.Windows.Forms.SendKeys]::SendWait($installRoot)
  [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
  Start-Sleep -Milliseconds 600
}

foreach ($b in $dlg.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  if ($b.Current.Name -match 'Select Folder') {
    $b.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
    Write-Output "SELECT_CLICKED"
    break
  }
}

Start-Sleep -Seconds 2
Write-Output "DONE installRoot=$installRoot"
Write-Output "NEXT paste OpenAI key in the extension popup, then pin the icon."
