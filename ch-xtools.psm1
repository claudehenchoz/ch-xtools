$ScriptURL = "https://raw.githubusercontent.com/claudehenchoz/ch-xtools/master/install-ch-xtools.ps1"

function Update-chxtools {
    iex ((new-object net.webclient).DownloadString($ScriptURL))
}

function Get-EnterpriseModeDetails {
    # Gets details on IE Enterprise Mode configuration (on IE11+)
    Param([switch]$ClearCache)
    $Reg = "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main\EnterpriseMode"
    $SiteListURL = Get-ItemProperty $Reg -Name SiteList | `
                       Select-Object -ExpandProperty SiteList

    [xml]$XmlDoc = (New-Object System.Net.WebClient).DownloadString($SiteListURL)
    $SiteListVersion = $XmlDoc.DocumentElement.GetAttribute("version")

    $RegHKCU = "HKCU:\Software\Microsoft\Internet Explorer\Main\EnterpriseMode"
    $LocalVersion = Get-ItemProperty $RegHKCU -Name CurrentVersion | `
                        Select-Object -ExpandProperty CurrentVersion

    "Enterprise Mode Details`n-----------------------`n"
    "Site List`n---------"
    "`tURL (HKLM Policy):`n`t`t$SiteListURL`n"
    "`tVersion:`n`t`t$SiteListVersion`n"
    "Local`n---------"
    "`tSite List Version (HKCU):`n`t`t$LocalVersion`n"
    "`tCache Folder:`n`t`t$([Environment]::GetFolderPath("InternetCache"))`n"

    if ($ClearCache) {
        RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 255
        explorer.exe $([Environment]::GetFolderPath("InternetCache"))
    }
}

function Format-FileSize {
    # Used by Get-FolderSizes to return a human-readable size representation
    Param([long]$Size)
    If     ($Size -gt 1TB) {[string]::Format("{0:0.0} TB", $Size / 1TB)}
    ElseIf ($Size -gt 1GB) {[string]::Format("{0:0.0} GB", $Size / 1GB)}
    ElseIf ($Size -gt 1MB) {[string]::Format("{0:0.0} MB", $Size / 1MB)}
    ElseIf ($Size -gt 1KB) {[string]::Format("{0:0.0} kB", $Size / 1KB)}
    ElseIf ($Size -gt 0)   {[string]::Format("{0:0.0} B", $Size)}
    Else                   {""}
}

function Get-ChildItemsWithoutSymlinks {
    # Used by Get-FolderSizes to retrieve recursive items without symlinks
    Param([Parameter(Mandatory=$true,Position=0)][string]$Path)
    Get-ChildItem -Directory -Force -Path $Path `
        -Attributes !ReparsePoint `
        -ErrorAction SilentlyContinue | % {
        Get-ChildItemsWithoutSymlinks $_.Fullname
    }
    Get-ChildItem -File -Force $Path -ErrorAction SilentlyContinue
}

function Get-FolderSizes {
    # Gets subfolders of $Path and displays their total size
    Param([Parameter(Mandatory=$true,Position=0)][string]$Path)
    Get-ChildItem -Directory -Force -Path $Path | % {
        Get-ChildItemsWithoutSymlinks $_.Fullname | `
            Measure-Object -Property Length -Sum | `
                Add-Member -MemberType NoteProperty -Name Folder `
                -Value $_.Fullname -PassThru | `
                Select-Object -Property Folder, `
                    @{Name="Bytes"; Expression={$_.Sum}}, `
                    @{Name="Size";Expression={Format-FileSize($_.Sum)}}
    }
}

function tail { 
    # Displays the last lines of a textfile and updates in realtime
    gc -Tail 10 -Wait $args
}

function Find-StringInFiles { 
    Get-ChildItem -recurse | Select-String -Pattern "$args" | Group Path | Select Name
}

function Measure-100Commands ($command) {
    # Runs a command 100 times and measures the time it takes to execute it
    1..100 | foreach {Measure-Command -Expression {Invoke-Expression $command}} |
             Measure-Object -Property TotalMilliseconds -Average
}

function Select-GUI ($input) {
    # Presents a selection table with checkboxes
    $c=@($input);if($c.Count -eq 0){Write-Error "Nothing piped";return}
    Add-Type -Assembly System.Windows.Forms;$a=New-Object Windows.Forms.Form
    $a.Size=New-Object Drawing.Size @(1024,600);$b=New-Object `
    Windows.Forms.CheckedListBox;$b.CheckOnClick=$true;$b.Dock="Fill"
    $a.Text="Select";$b.Items.AddRange($c);$d=New-Object Windows.Forms.Panel
    $d.Size=New-Object Drawing.Size @(600,30);$d.Dock="Bottom";$e=New-Object `
    Windows.Forms.Button;$e.Text="Cancel";$e.DialogResult="Cancel"
    $e.Top=$d.Height-$e.Height-5;$e.Left=$d.Width-$e.Width-10;$e.Anchor="Right"
    $f=New-Object Windows.Forms.Button;$f.Text="Ok";$f.DialogResult="Ok"
    $f.Top=$e.Top;$f.Left=$e.Left-$f.Width-5;$f.Anchor="Right"
    $d.Controls.Add($f);$d.Controls.Add($e);$a.Controls.Add($b)
    $a.Controls.Add($d);$a.AcceptButton=$f;$a.CancelButton=$e
    $a.Add_Shown({$a.Activate()});$g=$a.ShowDialog()
    if($g -eq "OK"){foreach($h in $b.CheckedIndices){$c[$h]}}
}


Export-ModuleMember -Function Get-FolderSizes, Find-StringInFiles, Measure-100Commands, Select-GUI
