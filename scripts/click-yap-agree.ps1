Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms

function Get-Chrome {
  $root = [System.Windows.Automation.AutomationElement]::RootElement
  $winCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Window
  )
  foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
    if ($w.Current.Name -match 'Google Chrome') { return $w }
  }
  return $null
}

function Set-Url($chrome, $url) {
  $editCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Edit
  )
  foreach ($e in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)) {
    if ($e.Current.Name -eq 'Address and search bar') {
      $e.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue($url)
      $e.SetFocus()
      [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
      return
    }
  }
}

$chrome = Get-Chrome
Set-Url $chrome "https://www.linkedin.com/feed/"
Start-Sleep -Seconds 7
$chrome = Get-Chrome
$btnCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Button
)
$hits = @()
foreach ($b in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  $n = $b.Current.Name
  if ($n -match 'TWA Reply|TWA جاهز|^T$') { $hits += $n }
}
Write-Output "TITLE=$($chrome.Current.Name)"
Write-Output "HITS=$($hits -join ' | ')"
Write-Output "HIT_COUNT=$($hits.Count)"
