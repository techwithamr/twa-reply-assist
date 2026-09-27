Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$root = [System.Windows.Automation.AutomationElement]::RootElement
$winCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Window
)
$chrome = $null
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
  if ($w.Current.Name -match 'Extensions') { $chrome = $w }
}
if (-not $chrome) { throw "NO_CHROME" }

$btnCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Button
)
foreach ($w in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $winCond)) {
  if ($w.Current.Name -match 'Failed to load') {
    foreach ($b in $w.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
      if ($b.Current.Name -eq 'Cancel') {
        $b.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
        Write-Output "CANCELLED_ERROR"
      }
    }
  }
}
Start-Sleep -Milliseconds 500

$dlg = $null
foreach ($w in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $winCond)) {
  if ($w.Current.Name -match 'Select the extension directory') { $dlg = $w }
}
if (-not $dlg) { throw "NO_DLG" }

$trueCond = [System.Windows.Automation.Condition]::TrueCondition
$all = $dlg.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)
Write-Output "CTRL_COUNT=$($all.Count)"
foreach ($c in $all) {
  $n = $c.Current.Name
  $id = $c.Current.AutomationId
  $ct = $c.Current.ControlType.ProgrammaticName
  if ($n -or $id) {
    if ($n -match 'Folder|Select|Cancel|Open|File|Directory|twa' -or $id -match '1152|1$|FileName') {
      Write-Output "$ct name='$n' id='$id'"
    }
  }
}
