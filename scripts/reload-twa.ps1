Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms

$root = [System.Windows.Automation.AutomationElement]::RootElement
$winCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Window
)
$chrome = $null
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
  if ($w.Current.Name -match 'Google Chrome') { $chrome = $w; break }
}
if (-not $chrome) { throw "NO_CHROME" }

$editCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Edit
)
$omnibox = $null
foreach ($e in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)) {
  if ($e.Current.Name -eq 'Address and search bar') { $omnibox = $e; break }
}
$omnibox.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue("chrome://extensions")
$omnibox.SetFocus()
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Start-Sleep -Seconds 2

$chrome = $null
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
  if ($w.Current.Name -match 'Extensions') { $chrome = $w; break }
}
if (-not $chrome) { throw "NO_EXTENSIONS" }

$btnCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Button
)
$reloaded = $false
foreach ($b in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  $n = $b.Current.Name
  if ($n -match 'Reload TWA|Reload.*Reply Assist|Reload.*TWA') {
    $b.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
    Write-Output "RELOADED=$n"
    $reloaded = $true
  }
}
if (-not $reloaded) {
  foreach ($b in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
    if ($b.Current.Name -match 'TWA Reply|Reply Assist') { Write-Output "NEAR=$($b.Current.Name)" }
    if ($b.Current.Name -eq 'Reload') { Write-Output "RELOAD_BTN id=$($b.Current.AutomationId)" }
  }
  throw "NO_RELOAD"
}
