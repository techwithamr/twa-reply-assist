Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class KeySend2 {
  [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  public const uint KEYUP = 2;
  public static void AltShiftR() {
    keybd_event(0x12, 0, 0, 0);
    keybd_event(0x10, 0, 0, 0);
    keybd_event(0x52, 0, 0, 0);
    keybd_event(0x52, 0, KEYUP, 0);
    keybd_event(0x10, 0, KEYUP, 0);
    keybd_event(0x12, 0, KEYUP, 0);
  }
}
"@

$root = [System.Windows.Automation.AutomationElement]::RootElement
$winCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Window
)
$chrome = $null
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
  if ($w.Current.Name -match 'Google Chrome') { $chrome = $w; break }
}
[KeySend2]::ShowWindow($chrome.Current.NativeWindowHandle, 3) | Out-Null
Start-Sleep -Milliseconds 300

$editCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Edit
)
foreach ($e in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)) {
  if ($e.Current.Name -eq 'Address and search bar') {
    $e.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue("https://www.linkedin.com/feed/")
    $e.SetFocus()
    [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
    break
  }
}
Start-Sleep -Seconds 6
[KeySend2]::SetForegroundWindow($chrome.Current.NativeWindowHandle) | Out-Null
Start-Sleep -Milliseconds 400
[System.Windows.Forms.SendKeys]::SendWait("{F5}")
Start-Sleep -Seconds 5
[KeySend2]::SetForegroundWindow($chrome.Current.NativeWindowHandle) | Out-Null
Start-Sleep -Milliseconds 300
[KeySend2]::AltShiftR()
Write-Output "SENT"
Start-Sleep -Seconds 1
Write-Output "TITLE=$($chrome.Current.Name)"
