Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$root = [System.Windows.Automation.AutomationElement]::RootElement
$winCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Window
)
$chrome = $null
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
  if ($w.Current.Name -match 'Extensions|إضافات') { $chrome = $w; Write-Output "WIN=$($w.Current.Name)" }
}
if (-not $chrome) { throw "NO_EXTENSIONS_WINDOW" }

$btnCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Button
)
$btns = $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
Write-Output "BTN_COUNT=$($btns.Count)"
foreach ($b in $btns) {
  Write-Output "BTN name='$($b.Current.Name)' id='$($b.Current.AutomationId)'"
}

$target = $null
foreach ($b in $btns) {
  if ($b.Current.Name -match 'Load unpacked|Load Unpacked|تحميل') { $target = $b; break }
}
if (-not $target) { throw "NO_LOAD_BUTTON" }

$invoke = $target.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
$invoke.Invoke()
Write-Output "CLICKED=$($target.Current.Name)"
