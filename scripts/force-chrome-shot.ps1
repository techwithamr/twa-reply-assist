Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class FgShot {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@
[FgShot]::SetProcessDPIAware() | Out-Null

$chrome = Get-Process chrome -ErrorAction SilentlyContinue |
  Where-Object { $_.MainWindowTitle -match 'LinkedIn|Chrome' -and $_.MainWindowHandle -ne [IntPtr]::Zero } |
  Sort-Object { $_.MainWindowTitle -match 'LinkedIn' } -Descending |
  Select-Object -First 1
if (-not $chrome) { Write-Output "NO_CHROME"; exit 1 }

$hwnd = $chrome.MainWindowHandle
Write-Output "TARGET='$($chrome.MainWindowTitle)' hwnd=$hwnd"

[FgShot]::ShowWindow($hwnd, 9) | Out-Null
[FgShot]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero) # ALT down
[FgShot]::SetForegroundWindow($hwnd) | Out-Null
[FgShot]::BringWindowToTop($hwnd) | Out-Null
[FgShot]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero) # ALT up

$fg = [FgShot]::GetForegroundWindow()
$fgTid = [FgShot]::GetWindowThreadProcessId($fg, [ref]([uint]0))
$cur = [FgShot]::GetCurrentThreadId()
if ($fgTid -ne $cur) {
  [FgShot]::AttachThreadInput($cur, $fgTid, $true) | Out-Null
  [FgShot]::SetForegroundWindow($hwnd) | Out-Null
  [FgShot]::AttachThreadInput($cur, $fgTid, $false) | Out-Null
}
Start-Sleep -Milliseconds 800

$rect = New-Object FgShot+RECT
[FgShot]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
$w = $rect.Right - $rect.Left
$h = $rect.Bottom - $rect.Top
Write-Output "RECT=$($rect.Left),$($rect.Top),$w,$h FG=$([FgShot]::GetForegroundWindow())"
$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($rect.Left, $rect.Top, 0, 0, (New-Object System.Drawing.Size $w, $h))
. (Join-Path $PSScriptRoot "_repo-root.ps1")
$out = Join-Path $script:TwaRepoRoot "scripts\proof-owner-linkedin.png"
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output "SHOT=$out"
