Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class ExOpen {
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
[ExOpen]::SetProcessDPIAware() | Out-Null

$chromeProc = Get-Process chrome | Where-Object { $_.MainWindowTitle } | Select-Object -First 1
$hwnd = $chromeProc.MainWindowHandle
Get-Process Cursor -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | ForEach-Object {
  [ExOpen]::ShowWindow($_.MainWindowHandle, 6) | Out-Null
}
[ExOpen]::ShowWindow($hwnd, 3) | Out-Null
[ExOpen]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
[ExOpen]::SetForegroundWindow($hwnd) | Out-Null
[ExOpen]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
Start-Sleep -Milliseconds 400

$root = [System.Windows.Automation.AutomationElement]::RootElement
$winCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Window
)
$chrome = $null
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
  if ($w.Current.Name -match 'Chrome|كروم|LinkedIn') { $chrome = $w }
}

[System.Windows.Forms.SendKeys]::SendWait("{PGDN}")
Start-Sleep -Milliseconds 800
[System.Windows.Forms.SendKeys]::SendWait("{PGDN}")
Start-Sleep -Milliseconds 800

$btnCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Button
)
$trueCond = [System.Windows.Automation.Condition]::TrueCondition
foreach ($c in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
  $n = $c.Current.Name
  if ($n -and $n -match 'Comment|comment|Like|Repost|Add a') {
    $br = $c.Current.BoundingRectangle
    if ($br.Width -gt 0 -and $br.Y -gt 200 -and $br.Y -lt 1200) {
      Write-Output ("HIT {0},{1} {2}x{3} [{4}]" -f $br.X,$br.Y,$br.Width,$br.Height,$n)
    }
  }
}

$pick = $null
foreach ($b in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  $n = $b.Current.Name
  if ($n -match '^(Comment|Comment the|Leave a comment)' -or $n -eq 'Comment') {
    $br = $b.Current.BoundingRectangle
    if ($br.Y -gt 250 -and $br.Y -lt 1100 -and $br.X -lt 1400) {
      Write-Output ("CAND {0},{1} [{2}]" -f $br.X,$br.Y,$n)
      $pick = $b
      break
    }
  }
}
if (-not $pick) {
  foreach ($c in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
    if ($c.Current.Name -match 'Add a comment') {
      $pick = $c
      Write-Output "PICK_ADD=$($c.Current.Name)"
      break
    }
  }
}
if ($pick) {
  $br = $pick.Current.BoundingRectangle
  $x = [int]($br.X + $br.Width / 2)
  $y = [int]($br.Y + $br.Height / 2)
  Write-Output "CLICK=$x,$y $($pick.Current.Name)"
  [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($x, $y)
  Start-Sleep -Milliseconds 150
  [ExOpen]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 40
  [ExOpen]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
} else {
  Write-Output "NO_COMMENT_ACTION"
}
Start-Sleep -Seconds 2

$agree = $null
foreach ($b in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  if ($b.Current.Name -eq 'Agree') {
    if (-not $agree -or $b.Current.BoundingRectangle.Y -lt $agree.Current.BoundingRectangle.Y) { $agree = $b }
  }
}
if ($agree) {
  $br = $agree.Current.BoundingRectangle
  $x = [int]($br.X + $br.Width / 2)
  $y = [int]($br.Y + $br.Height / 2)
  Write-Output "AGREE=$x,$y"
  [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($x, $y)
  Start-Sleep -Milliseconds 120
  [ExOpen]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 40
  [ExOpen]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
}
Start-Sleep -Seconds 10

$r = New-Object ExOpen+RECT
[ExOpen]::GetWindowRect($hwnd, [ref]$r) | Out-Null
$w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.Left, $r.Top, 0, 0, (New-Object System.Drawing.Size $w, $h))
. (Join-Path $PSScriptRoot "_repo-root.ps1")
$out = Join-Path $script:TwaRepoRoot "scripts\extras-03-draft.png"
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output "SHOT=$out"

Get-Process Cursor -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | ForEach-Object {
  [ExOpen]::ShowWindow($_.MainWindowHandle, 9) | Out-Null
}
Write-Output "DONE"
