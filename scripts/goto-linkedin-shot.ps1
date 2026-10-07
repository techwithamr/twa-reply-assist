Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms
$root = [System.Windows.Automation.AutomationElement]::RootElement
$winCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Window)
$chrome = $null
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
  if ($w.Current.Name -match 'Google Chrome') { $chrome = $w; break }
}
$editCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Edit)
foreach ($e in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)) {
  if ($e.Current.Name -eq 'Address and search bar') {
    $e.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue("https://www.linkedin.com/feed/")
    $e.SetFocus()
    [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
    break
  }
}
Start-Sleep -Seconds 6
$chrome = $null
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
  if ($w.Current.Name -match 'Google Chrome') { $chrome = $w }
}
Write-Output "TITLE=$($chrome.Current.Name)"
$trueCond = [System.Windows.Automation.Condition]::TrueCondition
$count = 0
foreach ($c in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
  $n = $c.Current.Name
  if ($n -match 'TWA|شغال|Agree|Supportive') {
    $count++
    Write-Output "HIT=$n"
  }
}
Write-Output "HIT_COUNT=$count"
