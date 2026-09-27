Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class MouseClick {
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(int flags, int dx, int dy, int data, int extra);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public static void Click(int x, int y) {
    SetCursorPos(x, y);
    mouse_event(0x02, 0, 0, 0, 0);
    mouse_event(0x04, 0, 0, 0, 0);
  }
}
"@
[MouseClick]::SetProcessDPIAware() | Out-Null

function Click-El($el) {
  $r = $el.Current.BoundingRectangle
  $x = [int]($r.X + $r.Width / 2)
  $y = [int]($r.Y + $r.Height / 2)
  Write-Output "CLICK $x,$y name=$($el.Current.Name) id=$($el.Current.AutomationId)"
  [MouseClick]::Click($x, $y)
}

$root = [System.Windows.Automation.AutomationElement]::RootElement
$winCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Window
)
$chrome = $null
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
  if ($w.Current.Name -match 'Extensions') { $chrome = $w }
}
if (-not $chrome) { throw "NO_CHROME" }
$dlg = $null
foreach ($w in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $winCond)) {
  if ($w.Current.Name -match 'Select the extension') { $dlg = $w }
}
if (-not $dlg) { throw "NO_DLG" }

$trueCond = [System.Windows.Automation.Condition]::TrueCondition
$search = $null
$address = $null
$select = $null
foreach ($c in $dlg.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
  if ($c.Current.AutomationId -eq 'SearchEditBox') { $search = $c }
  if ($c.Current.AutomationId -eq '1001') { $address = $c }
  if ($c.Current.Name -eq 'Select Folder') { $select = $c }
}

if ($search) {
  $search.SetFocus()
  try {
    $search.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue("")
    Write-Output "SEARCH_CLEARED"
  } catch {
    Write-Output "SEARCH_CLEAR_FAIL"
  }
}

if ($address) {
  Click-El $address
  Start-Sleep -Milliseconds 250
  [System.Windows.Forms.SendKeys]::SendWait("C:\Github\twa-reply-assist")
  Start-Sleep -Milliseconds 200
  [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
  Write-Output "ADDRESS_TYPED"
  Start-Sleep -Milliseconds 800
}

# re-find Select Folder after navigation
foreach ($c in $dlg.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
  if ($c.Current.Name -eq 'Select Folder') { $select = $c }
}
if (-not $select) { throw "NO_SELECT" }
Click-El $select
Write-Output "SELECT_CLICKED"
