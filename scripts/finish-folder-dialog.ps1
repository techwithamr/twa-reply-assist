Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

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

$allWins = $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $winCond)
Write-Output "DESC_WINS=$($allWins.Count)"
foreach ($w in $allWins) { Write-Output "CHILD=$($w.Current.Name)" }

$err = $null
$dlg = $null
foreach ($w in $allWins) {
  if ($w.Current.Name -match 'Failed to load') { $err = $w }
  if ($w.Current.Name -match 'Select the extension directory') { $dlg = $w }
}

$btnCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Button
)

if ($err) {
  Write-Output "DISMISS_ERROR=$($err.Current.Name)"
  foreach ($b in $err.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
    Write-Output "ERR_BTN=$($b.Current.Name)"
    if ($b.Current.Name -match 'OK|حسنا') {
      $b.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
      Write-Output "CLICKED_OK"
    }
  }
  Start-Sleep -Milliseconds 400
}

if (-not $dlg) {
  foreach ($w in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $winCond)) {
    if ($w.Current.Name -match 'Select the extension directory') { $dlg = $w }
  }
}
if (-not $dlg) { throw "NO_FOLDER_DIALOG" }

Write-Output "DLG=$($dlg.Current.Name)"
$editCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Edit
)
foreach ($e in $dlg.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)) {
  Write-Output "EDIT name='$($e.Current.Name)' id='$($e.Current.AutomationId)'"
  if ($e.Current.Name -eq 'Folder:' -or $e.Current.AutomationId -eq '1152') {
    $e.SetFocus()
    $val = $e.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
    . (Join-Path $PSScriptRoot "_repo-root.ps1")
    $val.SetValue($script:TwaRepoRoot)
    Write-Output "SET_FOLDER"
  }
}

foreach ($b in $dlg.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  Write-Output "BTN=$($b.Current.Name) id=$($b.Current.AutomationId)"
  if ($b.Current.Name -match 'Select Folder|Select folder') {
    $b.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
    Write-Output "CLICKED_SELECT"
  }
}
