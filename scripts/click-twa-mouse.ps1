Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class MouseClick {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
  [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, UIntPtr dwExtraInfo);
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@
[MouseClick]::SetProcessDPIAware() | Out-Null

$chromeProc = Get-Process chrome | Where-Object { $_.MainWindowTitle } | Select-Object -First 1
$hwnd = $chromeProc.MainWindowHandle
Write-Output "TITLE=$($chromeProc.MainWindowTitle)"

Get-Process Cursor -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | ForEach-Object {
  [MouseClick]::ShowWindow($_.MainWindowHandle, 6) | Out-Null
}
[MouseClick]::ShowWindow($hwnd, 3) | Out-Null # maximize
[MouseClick]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
[MouseClick]::BringWindowToTop($hwnd) | Out-Null
[MouseClick]::SetForegroundWindow($hwnd) | Out-Null
[MouseClick]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 600

$root = [System.Windows.Automation.AutomationElement]::RootElement
$winCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Window
)
$chrome = $null
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
  if ($w.Current.Name -match 'Chrome|كروم|LinkedIn') { $chrome = $w }
}
$btnCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Button
)
$twa = $null
foreach ($b in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  if ($b.Current.Name -match 'TWA Reply Assist') {
    $twa = $b
    $br = $b.Current.BoundingRectangle
    Write-Output ("TWA rect={0},{1} {2}x{3} name={4}" -f $br.X,$br.Y,$br.Width,$br.Height,$b.Current.Name)
  }
}
if (-not $twa) { throw "NO_TWA" }

$br = $twa.Current.BoundingRectangle
$x = [int]($br.X + $br.Width / 2)
$y = [int]($br.Y + $br.Height / 2)
Write-Output "CLICK_XY=$x,$y"
[System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($x, $y)
Start-Sleep -Milliseconds 200
[MouseClick]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 40
[MouseClick]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
Start-Sleep -Seconds 2

function Save-Shot([IntPtr]$h, [string]$name) {
  $r = New-Object MouseClick+RECT
  [MouseClick]::GetWindowRect($h, [ref]$r) | Out-Null
  $w = $r.Right - $r.Left
  $ht = $r.Bottom - $r.Top
  $bmp = New-Object System.Drawing.Bitmap $w, $ht
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($r.Left, $r.Top, 0, 0, (New-Object System.Drawing.Size $w, $ht))
  . (Join-Path $PSScriptRoot "_repo-root.ps1")
  $out = Join-Path $script:TwaRepoRoot "scripts\$name"
  $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Write-Output "SHOT=$out $($w)x$($ht)"
}

Save-Shot $hwnd "real-06-popup.png"
Start-Sleep -Milliseconds 400
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
Start-Sleep -Milliseconds 700
Save-Shot $hwnd "real-07-feed.png"

Get-Process Cursor -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | ForEach-Object {
  [MouseClick]::ShowWindow($_.MainWindowHandle, 9) | Out-Null
}
Write-Output "DONE"
