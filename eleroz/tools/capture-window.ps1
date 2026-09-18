param([string]$OutPath)
# Windows PowerShell 5.1: find visible Flutter windows of processes started from %LOCALAPPDATA%\elerozconnect
# and capture each one with PrintWindow(PW_RENDERFULLCONTENT). ASCII-only on purpose.
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Text; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class Cap3 {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint f);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  public static string ListFor(uint wantPid) {
    var sb = new StringBuilder();
    EnumWindows((h, l) => { uint pid; GetWindowThreadProcessId(h, out pid);
      if (pid == wantPid && IsWindowVisible(h)) { var c = new StringBuilder(256); GetClassName(h, c, 256);
        if (c.ToString() == "FLUTTER_RUNNER_WIN32_WINDOW") { sb.Append(h.ToInt64()).Append('\n'); } } return true; }, IntPtr.Zero);
    return sb.ToString();
  }
  public static string Title(long hwnd) { var t = new StringBuilder(256); GetWindowText(new IntPtr(hwnd), t, 256); return t.ToString(); }
  public static string Shot(long hwnd, string path) {
    var h = new IntPtr(hwnd); RECT r; GetWindowRect(h, out r);
    int w = r.R - r.L, hh = r.B - r.T;
    using (var bmp = new Bitmap(w, hh)) { using (var g = Graphics.FromImage(bmp)) { var hdc = g.GetHdc(); PrintWindow(h, hdc, 2); g.ReleaseHdc(hdc); } bmp.Save(path, ImageFormat.Png); }
    return w + "x" + hh;
  }
}
"@
$procs = Get-WmiObject Win32_Process | Where-Object { $_.ExecutablePath -like "*\AppData\Local\elerozconnect-portable\*" }
$i = 0
foreach ($pr in $procs) {
  Write-Output ("process {0}: {1}" -f $pr.ProcessId, $pr.CommandLine)
  foreach ($h in (([Cap3]::ListFor([uint32]$pr.ProcessId)) -split "`n" | Where-Object { $_ })) {
    $i++
    $file = $OutPath -replace '\.png$', ("-" + $i + ".png")
    $size = [Cap3]::Shot([long]$h, $file)
    $titleCodes = ([Cap3]::Title([long]$h)).ToCharArray() | ForEach-Object { [int]$_ }
    Write-Output ("  window {0} size {1} -> {2}; title codepoints: {3}" -f $h, $size, $file, ($titleCodes -join ','))
  }
}
if ($i -eq 0) { Write-Output "no visible Flutter window found" }

