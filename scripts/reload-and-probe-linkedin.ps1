Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class KeySend {
  [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  public const uint KEYUP = 2;
  public static void AltShiftR() {
    keybd_event(0x12, 0, 0, 0); // ALT
    keybd_event(0x10, 0, 0, 0); // SHIFT
    keybd_event(0x52, 0, 0, 0); // R
    keybd_event(0x52, 0, KEYUP, 0);
    keybd_event(0x10, 0, KEYUP, 0);
    keybd_event(0x12, 0, KEYUP, 0);
  }
}
"@

function Get-ChromeWindow([string]$pattern) {
  $root = [System.Windows.Automation.AutomationElement]::RootElement
  $winCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Window
  )
  foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
    if ($w.Current.Name -match $pattern) { return $w }
  }
  return $null
}

function Set-Omnibox($chrome, $url) {
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
  throw "NO_OMNIBOX"
}

$chrome = Get-ChromeWindow 'Google Chrome'
if (-not $chrome) { throw "NO_CHROME" }
Set-Omnibox $chrome "chrome://extensions"
Start-Sleep -Seconds 2
$chrome = Get-ChromeWindow 'Extensions|Google Chrome'
$btnCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Button
)
$reloaded = $false
foreach ($b in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  if ($b.Current.Name -match 'Reload.*TWA|Reload TWA Reply|Reload.*Reply Assist') {
    $b.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
    Write-Output "RELOAD=$($b.Current.Name)"
    $reloaded = $true
  }
}
if (-not $reloaded) {
  foreach ($b in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
    if ($b.Current.Name -match 'TWA|Reply Assist|Reload') { Write-Output "BTN=$($b.Current.Name)" }
  }
}

Start-Sleep -Milliseconds 800
Set-Omnibox $chrome "https://www.linkedin.com/feed/"
Start-Sleep -Seconds 5
[KeySend]::SetForegroundWindow($chrome.Current.NativeWindowHandle) | Out-Null
Start-Sleep -Milliseconds 400
[KeySend]::AltShiftR()
Write-Output "SENT_ALT_SHIFT_R"
Start-Sleep -Seconds 1
Write-Output "DONE"
