Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$root = [System.Windows.Automation.AutomationElement]::RootElement
$winCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Window
)
$chrome = $null
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
  if ($w.Current.Name -match 'LinkedIn|Google Chrome') { $chrome = $w }
}
$btnCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Button
)
$hits = 0
foreach ($b in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  if ($b.Current.Name -match 'رد|صياغة|TWA|Alt\+Shift') {
    $hits++
    Write-Output "HIT name='$($b.Current.Name)'"
  }
}
Write-Output "HIT_COUNT=$hits"
Write-Output "TITLE=$($chrome.Current.Name)"
