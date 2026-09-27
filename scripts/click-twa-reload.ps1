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

$editCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Edit
)
foreach ($e in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)) {
  if ($e.Current.Name -eq 'Address and search bar') {
    $e.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue("chrome://extensions")
    $e.SetFocus()
    [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
    break
  }
}
Start-Sleep -Seconds 2

foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
  if ($w.Current.Name -match 'Extensions|Google Chrome') { $chrome = $w }
}

$btnCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Button
)
$count = 0
foreach ($b in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  if ($b.Current.Name -eq 'Reload') {
    $b.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
    $count++
    Write-Output "CLICKED_RELOAD #$count"
    Start-Sleep -Milliseconds 200
  }
}
Write-Output "RELOAD_COUNT=$count"
