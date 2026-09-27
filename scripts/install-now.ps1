Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$root = [System.Windows.Automation.AutomationElement]::RootElement
$winCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Window
)
function Get-ChromeWindow {
  foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
    if ($w.Current.Name -match 'Google Chrome') { return $w }
  }
  return $null
}

$chrome = Get-ChromeWindow
if (-not $chrome) { throw "NO_CHROME" }

$editCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Edit
)
$omnibox = $null
foreach ($e in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)) {
  if ($e.Current.Name -eq 'Address and search bar') { $omnibox = $e; break }
}
if (-not $omnibox) { throw "NO_OMNIBOX" }
$omnibox.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue("chrome://extensions")
$omnibox.SetFocus()
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Write-Output "NAV"

$ok = $false
for ($i = 0; $i -lt 20; $i++) {
  Start-Sleep -Milliseconds 250
  $chrome = Get-ChromeWindow
  if ($chrome.Current.Name -match 'Extensions') { $ok = $true; break }
}
if (-not $ok) { throw "NOT_ON_EXTENSIONS $($chrome.Current.Name)" }
Write-Output "ON_EXTENSIONS"

$btnCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Button
)
$load = $null
foreach ($b in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  if ($b.Current.AutomationId -eq 'loadUnpacked') { $load = $b; break }
}
if (-not $load) { throw "NO_LOAD" }
$load.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Write-Output "CLICKED_LOAD"

$dlg = $null
for ($i = 0; $i -lt 25; $i++) {
  Start-Sleep -Milliseconds 200
  $chrome = Get-ChromeWindow
  foreach ($w in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $winCond)) {
    if ($w.Current.Name -eq 'Select the extension directory.') { $dlg = $w; break }
  }
  if ($dlg) { break }
}
if (-not $dlg) { throw "NO_DLG" }
Write-Output "DLG_OPEN"

$folderEdit = $null
foreach ($e in $dlg.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)) {
  if ($e.Current.Name -eq 'Folder:' -or $e.Current.AutomationId -eq '1152') { $folderEdit = $e }
}
if ($folderEdit) {
  $folderEdit.SetFocus()
  $folderEdit.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue("C:\Github\twa-reply-assist")
  Write-Output "FOLDER_SET"
} else {
  throw "NO_FOLDER_EDIT"
}

$clicked = $false
foreach ($b in $dlg.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  if ($b.Current.Name -match 'Select Folder') {
    $b.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
    Write-Output "CLICKED $($b.Current.Name)"
    $clicked = $true
  }
}
if (-not $clicked) {
  Write-Output "SELECT_NOT_FOUND listing buttons"
  foreach ($b in $dlg.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
    Write-Output "BTN $($b.Current.Name) $($b.Current.AutomationId)"
  }
  throw "NO_SELECT"
}
Write-Output "DONE_CLICK"
