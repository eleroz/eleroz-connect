param([Parameter(Mandatory = $true)][string]$Msi)
# Читает таблицы MSI через WindowsInstaller.Installer, ничего не устанавливая.
$installer = New-Object -ComObject WindowsInstaller.Installer
$db = $installer.GetType().InvokeMember("OpenDatabase", "InvokeMethod", $null, $installer, @($Msi, 0))

function Invoke-MsiQuery([string]$Sql) {
    $view = $db.GetType().InvokeMember("OpenView", "InvokeMethod", $null, $db, @($Sql))
    $view.GetType().InvokeMember("Execute", "InvokeMethod", $null, $view, $null) | Out-Null
    while ($true) {
        $rec = $view.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $view, $null)
        if ($null -eq $rec) { break }
        $count = $rec.GetType().InvokeMember("FieldCount", "GetProperty", $null, $rec, $null)
        $vals = @()
        for ($i = 1; $i -le $count; $i++) {
            $vals += $rec.GetType().InvokeMember("StringData", "GetProperty", $null, $rec, @($i))
        }
        ($vals -join "  |  ")
    }
    $view.GetType().InvokeMember("Close", "InvokeMethod", $null, $view, $null) | Out-Null
}

"=== Property"
Invoke-MsiQuery "SELECT Property, Value FROM Property WHERE Property = 'ProductName' OR Property = 'Manufacturer' OR Property = 'ProductLanguage' OR Property = 'ProductVersion' OR Property = 'ARPCONTACT' OR Property = 'ARPHELPLINK' OR Property = 'ARPREADME' OR Property = 'ARPSYSTEMCOMPONENT' OR Property = 'UpgradeCode'"
"=== Directory (папки установки)"
Invoke-MsiQuery "SELECT Directory, DefaultDir FROM Directory WHERE Directory = 'INSTALLFOLDER_INNER' OR Directory = 'App.StartMenu' OR Directory = 'App.Data.Folder'"
"=== Shortcut (ярлыки)"
Invoke-MsiQuery "SELECT Shortcut, Directory_, Name, Arguments FROM Shortcut"
"=== Registry: запись в «Программах и компонентах»"
Invoke-MsiQuery "SELECT Key, Name, Value FROM Registry WHERE Name = 'DisplayName' OR Name = 'Publisher' OR Name = 'DisplayIcon' OR Name = 'Comments'"
"=== CustomAction: имена служебных процессов"
Invoke-MsiQuery "SELECT Action, Target FROM CustomAction WHERE Action = 'TerminateBrokers.SetParam' OR Action = 'TryDeleteStartupShortcut.SetParam' OR Action = 'CreateStartService.SetParam'"
"=== Файл программы"
Invoke-MsiQuery "SELECT File, FileName FROM File WHERE File = 'App.exe'"
