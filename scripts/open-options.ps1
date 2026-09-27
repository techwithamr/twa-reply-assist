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
  if ($w.Current.Name -match 'Google Chrome') { $chrome = $w }
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
$url = "chrome-extension://noafjmnihfhcjfmfhfdmeecpmmphpbpn/options/options.html"
$omnibox.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue($url)
$omnibox.SetFocus()
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Write-Output "OPENED_OPTIONS"
