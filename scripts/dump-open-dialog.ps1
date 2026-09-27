Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$root = [System.Windows.Automation.AutomationElement]::RootElement
$winCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Window
)
$chrome = $null
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
  if ($w.Current.Name -match 'Google Chrome') { $chrome = $w; Write-Output "WIN=$($w.Current.Name)" }
}
$dlg = $null
foreach ($w in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $winCond)) {
  Write-Output "CHILD=$($w.Current.Name)"
  if ($w.Current.Name -match 'Select the extension') { $dlg = $w }
}
if (-not $dlg) { throw "NO_DLG" }
$trueCond = [System.Windows.Automation.Condition]::TrueCondition
$count = 0
foreach ($c in $dlg.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
  $n = $c.Current.Name
  $id = $c.Current.AutomationId
  if ($n -or $id) {
    $count++
    if ($count -le 80) {
      Write-Output "$($c.Current.ControlType.ProgrammaticName) | $n | $id"
    }
  }
}
Write-Output "NAMED=$count"
