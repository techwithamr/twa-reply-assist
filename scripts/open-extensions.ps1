Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinApi2 {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[WinApi2]::SetProcessDPIAware() | Out-Null
$proc = Get-Process chrome | Where-Object { $_.MainWindowTitle } | Select-Object -First 1
if (-not $proc) { throw "NO_CHROME_WINDOW" }
[WinApi2]::ShowWindow($proc.MainWindowHandle, 3) | Out-Null
Start-Sleep -Milliseconds 500
[WinApi2]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 400
[System.Windows.Forms.SendKeys]::SendWait("^l")
Start-Sleep -Milliseconds 300
[System.Windows.Forms.SendKeys]::SendWait("chrome://extensions/")
Start-Sleep -Milliseconds 200
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Start-Sleep -Seconds 2
Write-Output "NAV_SENT title=$($proc.MainWindowTitle)"
