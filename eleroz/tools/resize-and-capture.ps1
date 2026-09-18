param([int]$X, [int]$Y, [string]$OutPath, [int]$Width = 0, [int]$Height = 0)
# Windows PowerShell 5.1: find the ELEROZ Connect window, optionally resize it,
# click at a point given in screenshot pixels, then capture the window. ASCII-only.
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Text; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class Cap4 {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
  [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr wParam, IntPtr lParam);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  public static long Find(uint wantPid) {
    long found = 0;
    EnumWindows((h, l) => { uint pid; GetWindowThreadProcessId(h, out pid);
      if (pid == wantPid && IsWindowVisible(h)) { var c = new StringBuilder(256); GetClassName(h, c, 256);
        if (c.ToString() == "FLUTTER_RUNNER_WIN32_WINDOW") { found = h.ToInt64(); return false; } } return true; }, IntPtr.Zero);
    return found;
  }
  public static void Resize(long hwnd, int w, int h) {
    SetWindowPos(new IntPtr(hwnd), IntPtr.Zero, 0, 0, w, h, 0x0002 | 0x0004 | 0x0010); // NOMOVE|NOZORDER|NOACTIVATE
  }
  public static string Click(long hwnd, int px, int py) {
    var h = new IntPtr(hwnd); RECT wr; GetWindowRect(h, out wr);
    POINT origin = new POINT(); ClientToScreen(h, ref origin);
    int cx = wr.L + px - origin.X, cy = wr.T + py - origin.Y;
    IntPtr lp = new IntPtr((cy << 16) | (cx & 0xFFFF));
    SendMessage(h, 0x0200, IntPtr.Zero, lp);            // WM_MOUSEMOVE
    SendMessage(h, 0x0201, new IntPtr(1), lp);          // WM_LBUTTONDOWN
    System.Threading.Thread.Sleep(60);
    SendMessage(h, 0x0202, IntPtr.Zero, lp);            // WM_LBUTTONUP
    return "client " + cx + "," + cy;
  }
  public static string Shot(long hwnd, string path) {
    var h = new IntPtr(hwnd); RECT r; GetWindowRect(h, out r);
    int w = r.R - r.L, hh = r.B - r.T;
    using (var bmp = new Bitmap(w, hh)) { using (var g = Graphics.FromImage(bmp)) { var hdc = g.GetHdc(); PrintWindow(h, hdc, 2); g.ReleaseHdc(hdc); } bmp.Save(path, ImageFormat.Png); }
    return w + "x" + hh;
  }
}
"@
$proc = Get-WmiObject Win32_Process | Where-Object { $_.ExecutablePath -like "*\AppData\Local\elerozconnect-portable\*" } | Select-Object -First 1
if (-not $proc) { Write-Output "no process"; exit 1 }
$hwnd = [Cap4]::Find([uint32]$proc.ProcessId)
if ($hwnd -eq 0) { Write-Output "no window"; exit 1 }
if ($Width -gt 0) { [Cap4]::Resize($hwnd, $Width, $Height); Start-Sleep -Milliseconds 800 }
if ($X -gt 0) { Write-Output ([Cap4]::Click($hwnd, $X, $Y)); Start-Sleep -Milliseconds 900 }
Write-Output ([Cap4]::Shot($hwnd, $OutPath))
