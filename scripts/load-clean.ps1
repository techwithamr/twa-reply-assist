Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

function Get-ChromeExtensions {
  $root = [System.Windows.Automation.AutomationElement]::RootElement
  $winCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Window
  )
  foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
    if ($w.Current.Name -match 'Extensions') { return $w }
  }
  return $null
}

$chrome = Get-ChromeExtensions
if (-not $chrome) { throw "NO_EXTENSIONS" }

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

$winCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Window
)
$dlg = $null
for ($i = 0; $i -lt 20; $i++) {
  Start-Sleep -Milliseconds 200
  $chrome = Get-ChromeExtensions
  foreach ($w in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $winCond)) {
    if ($w.Current.Name -eq 'Select the extension directory.') { $dlg = $w; break }
  }
  if ($dlg) { break }
}
if (-not $dlg) { throw "NO_DLG" }
Write-Output "HAS_DLG"

$trueCond = [System.Windows.Automation.Condition]::TrueCondition
foreach ($c in $dlg.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
  $n = $c.Current.Name
  if ($n) { Write-Output "$($c.Current.ControlType.ProgrammaticName) | $n | $($c.Current.AutomationId)" }
}
