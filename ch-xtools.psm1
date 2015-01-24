$ScriptURL = "https://raw.githubusercontent.com/claudehenchoz/ch-xtools/master/install-ch-xtools.ps1"

function Update-chxtools {
    iex ((new-object net.webclient).DownloadString($ScriptURL))
}

Export-ModuleMember -Function Update-chxtools

$EmReg = "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main\EnterpriseMode"
$EmRegHKCU = "HKCU:\Software\Microsoft\Internet Explorer\Main\EnterpriseMode"

function Get-EnterpriseModeSiteList {
    # Gets a human-readable representation of the Enterprise Mode site list
    Param([Parameter(Mandatory=$false,Position=0)][string]$Url)

    function NoTrailingSlashToAsterisk {
        Param([Parameter(Mandatory=$true,Position=0)][string]$Part)
        if ($Path."#text"[-1] -eq "/") {
            $Part
        } else {
            $Part+"*"
        }
    }

    if (!$Url) {
        if ((Test-Path $EmReg)) {
            $Url = Get-ItemProperty $EmReg -Name SiteList | `
                               Select-Object -ExpandProperty SiteList
        } else {
            "No Url specified and none configured in $EmReg"
            break
        }
    }
    [xml]$XmlDoc = (New-Object System.Net.WebClient).DownloadString($Url)
    if ($XmlDoc) {
        # emie section
        $Domains = $XmlDoc.documentElement.emie.getElementsByTagName("domain")
        foreach ($Domain in $Domains) {
            if ($Domain.hasAttribute("exclude")) {
                if ($Domain.getAttribute("exclude") -eq "false") {
                    [PSCustomObject]@{
                        Address = $Domain."#text" + "*"
                        Setting = "Enterprise Mode"
                    }
                } else {
                    [PSCustomObject]@{
                        Address = $Domain."#text" + "*"
                        Setting = "Default"
                    }
                }
            } else {
                [PSCustomObject]@{
                    Address = $Domain."#text" + "*"
                    Setting = "N/A (broken configuration)"
                }
            }
            $Paths = $Domain.getElementsByTagName("path")
            foreach ($Path in $Paths) {
                $FullAddress = $Domain."#text" + $Path."#text"
                if ($Path.hasAttribute("exclude")) {
                    if ($Path.getAttribute("exclude") -eq "false") {
                        [PSCustomObject]@{
                            Address = NoTrailingSlashToAsterisk($FullAddress)
                            Setting = "Enterprise Mode"
                        }
                    } else {
                        [PSCustomObject]@{
                            Address = NoTrailingSlashToAsterisk($FullAddress)
                            Setting = "Default"
                        }
                    }
                } else {
                    [PSCustomObject]@{
                        Address = NoTrailingSlashToAsterisk($FullAddress)
                        Setting = "N/A (broken configuration)"
                    }
                }
            }
        }
        # docMode section
        $Domains = $XmlDoc.documentElement.docMode.getElementsByTagName("domain")
        foreach ($Domain in $Domains) {
            if ($Domain.hasAttribute("docMode")) {
                [PSCustomObject]@{
                    Address = $Domain."#text" + "*"
                    Setting = $Domain.getAttribute("docMode")
                }
            } else {
                [PSCustomObject]@{
                    Address = $Domain."#text" + "*"
                    Setting = "No docMode"
                }
            }

            $Paths = $Domain.getElementsByTagName("path")
            foreach ($Path in $Paths) {
                $FullAddress = $Domain."#text" + $Path."#text"
                if ($Path.hasAttribute("docMode")) {
                    [PSCustomObject]@{
                        Address = NoTrailingSlashToAsterisk($FullAddress)
                        Setting = $Path.getAttribute("docMode")
                    }
                } else {
                    [PSCustomObject]@{
                        Address = NoTrailingSlashToAsterisk($FullAddress)
                        Setting = "No docMode"
                    }
                }
            }
        }
    }
}

Set-Alias gemsl Get-EnterpriseModeSiteList
Export-ModuleMember -Function Get-EnterpriseModeSiteList -Alias gemsl

function Test-XML {
    # Checks XML file against Schema (.xsd file)
    param ([Parameter(ValueFromPipeline=$true, Mandatory=$true)][string]$XmlFile,
           [Parameter(Mandatory=$true)][string]$SchemaFile,
           [scriptblock]$ValidationEventHandler={Write-Error $args[1].Exception})
    $xml = New-Object System.Xml.XmlDocument
    $schemaReader = New-Object System.Xml.XmlTextReader $SchemaFile
    $schema = [System.Xml.Schema.XmlSchema]::Read($schemaReader, $ValidationEventHandler)
    $xml.Schemas.Add($schema) | Out-Null
    $xml.Load($XmlFile)
    $xml.Validate($ValidationEventHandler)
}

Export-ModuleMember -Function Test-XML

function Convert-CSVToEnterpriseModeSiteList {
    Param([Parameter(Mandatory=$true,Position=0)][string]$CSVPath,
          [Parameter(Position=1)][switch]$EmieFile)
    # The sort by URL in this line ensures domains are always before URLs with path
    $CSVData = Import-Csv $CSVPath | Sort-Object -Property Url
    [xml]$XmlDoc = "<rules />"
    $Rules = $XmlDoc.DocumentElement
    if (!$EmieFile) {
        $RandomVersion = Get-Random -Minimum 10000 -maximum 99999
        $Rules.SetAttribute("version","$RandomVersion")
    }
    $Emie = $XmlDoc.CreateElement("","emie","")
    $Rules.AppendChild($Emie) | Out-Null
    $DocMode = $XmlDoc.CreateElement("","docMode","")
    $Rules.AppendChild($DocMode) | Out-Null
    foreach ($Configuration in $CSVData) {
        $ConfigUri = [System.Uri]$Configuration.Url
        $Authority = $ConfigUri.Authority
        $PathAndQuery = $ConfigUri.PathAndQuery
        if ($Configuration.Mode -eq "emie") {
            $Domain = $Emie.SelectNodes(".//domain[text()='$Authority']")
            if ($Domain.count -gt 0) {
                # Domain exists already
            } else {
                # Domain doesn't exist
                $Domain = $XmlDoc.CreateElement("domain")
                $Text = $XmlDoc.CreateTextNode($Authority)
                $Domain.AppendChild($Text) | Out-Null
                $Emie.AppendChild($Domain) | Out-Null
                if ($ConfigUri.Segments.Count -gt 1) {
                    # We set the domain to exclude as it wasn't 
                    # explicitly specified
                    $Domain.SetAttribute("exclude","true")
                    if ($EmieFile -and $Configuration.Comment) {
                        $Domain.SetAttribute("comment",$Configuration.Comment)
                    }
                } else {
                    # We enable emie as the URL contains only a domain
                    $Domain.SetAttribute("exclude","false")
                    if ($EmieFile -and $Configuration.Comment) {
                        $Domain.SetAttribute("comment",$Configuration.Comment)
                    }
                }
            }
            if ($ConfigUri.Segments.Count -gt 1) {
                $Path = $XmlDoc.CreateElement("path")
                $Path.SetAttribute("exclude","false")
                if ($EmieFile -and $Configuration.Comment) {
                    $Path.SetAttribute("comment",$Configuration.Comment)
                }
                $Text = $XmlDoc.CreateTextNode($PathAndQuery)
                $Path.AppendChild($Text) | Out-Null
                $Domain.AppendChild($Path) | Out-Null
            }
        }
        elseif ($Configuration.Mode.Substring(0,7) -eq "docMode") {
            $DocLevel = $Configuration.Mode.Substring(7)
            $Domain = $DocMode.SelectNodes(".//domain[text()='$Authority']")
            if ($Domain.count -gt 0) {
                # Domain exists already
            } else {
                # Domain doesn't exist
                $Domain = $XmlDoc.CreateElement("domain")
                $Text = $XmlDoc.CreateTextNode($Authority)
                $Domain.AppendChild($Text) | Out-Null
                $DocMode.AppendChild($Domain) | Out-Null
                if ($ConfigUri.Segments.Count -gt 1) {
                    # We don't configure the domain as it wasn't 
                    # explicitly specified
                    if ($EmieFile -and $Configuration.Comment) {
                        $Domain.SetAttribute("comment",$Configuration.Comment)
                    }
                } else {
                    # We configure the domain as the URL contains only a domain
                    $Domain.SetAttribute("docMode",$DocLevel)
                    if ($EmieFile -and $Configuration.Comment) {
                        $Domain.SetAttribute("comment",$Configuration.Comment)
                    }
                }
            }
            if ($ConfigUri.Segments.Count -gt 1) {
                $Path = $XmlDoc.CreateElement("path")
                $Path.SetAttribute("docMode",$DocLevel)
                if ($EmieFile -and $Configuration.Comment) {
                    $Path.SetAttribute("comment",$Configuration.Comment)
                }
                $Text = $XmlDoc.CreateTextNode($PathAndQuery)
                $Path.AppendChild($Text) | Out-Null
                $Domain.AppendChild($Path) | Out-Null
            }
        }
    }
    $XmlDoc.InnerXml
}

Export-ModuleMember -Function Convert-CSVToEnterpriseModeSiteList

function Get-EnterpriseModeDetails {
    # Gets details on IE Enterprise Mode configuration (on IE11+)
    Param([switch]$ClearCache,[switch]$OpenCacheFolder)
    if ((Test-Path $EmReg)) {
        $SiteListURL = Get-ItemProperty $EmReg -Name SiteList | `
                           Select-Object -ExpandProperty SiteList
        [xml]$XmlDoc = (New-Object System.Net.WebClient).DownloadString($SiteListURL)
        $SiteListVersion = $XmlDoc.DocumentElement.GetAttribute("version")
    } else {
        $SiteListURL = "n/a"
        $SiteListVersion = "n/a"
    }
    if ((Test-Path $EmRegHKCU)) {
        $LocalVersion = Get-ItemProperty $EmRegHKCU -Name CurrentVersion | `
                            Select-Object -ExpandProperty CurrentVersion
    } else {
        $LocalVersion = "n/a"
    }

    "Enterprise Mode Details`n-----------------------`n"
    "Site List`n---------"
    "`tURL (HKLM Policy):`n`t`t$SiteListURL`n"
    "`tVersion (Web):`n`t`t$SiteListVersion`n"
    "Local`n-----"
    "`tSite List Version (HKCU):`n`t`t$LocalVersion`n"
    "`tCache Folder:`n`t`t$([Environment]::GetFolderPath("InternetCache"))`n"

    if ($ClearCache) {
        RunDll32.exe InetCpl.cpl, ClearMyTracksByProcess 255
        explorer.exe $([Environment]::GetFolderPath("InternetCache"))
    }

    if ($OpenCacheFolder) {
        explorer.exe $([Environment]::GetFolderPath("InternetCache"))
    }
}

Set-Alias gemd Get-EnterpriseModeDetails
Export-ModuleMember -Function Get-EnterpriseModeDetails -Alias gemd

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

Set-Alias gfs Get-FolderSizes
Export-ModuleMember -Function Get-FolderSizes -Alias gfs

function tail { 
    # Displays the last lines of a textfile and updates in realtime
    gc -Tail 10 -Wait $args
}

function Find-StringInFiles { 
    Get-ChildItem -recurse | Select-String -Pattern "$args" | Group Path | Select Name
}

Export-ModuleMember -Function Find-StringInFiles

function Measure-100Commands ($command) {
    # Runs a command 100 times and measures the time it takes to execute it
    1..100 | foreach {Measure-Command -Expression {Invoke-Expression $command}} |
             Measure-Object -Property TotalMilliseconds -Average
}

Set-Alias m100 Measure-100Commands
Export-ModuleMember -Function Measure-100Commands -Alias m100

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

Export-ModuleMember -Function Select-GUI

function Confirm-MatchThresholdMet {
    # Returns true if a file has more than a specified percentage of matching lines
    # This can be used to detect a problem in a log file
    Param([Parameter(Mandatory=$true,Position=0)][string]$Path,
          [Parameter(Mandatory=$true,Position=1)][string]$Pattern,
          [Parameter(Position=2)][int]$MinPercent=20,
          [Parameter(Position=3)][int]$LastLines)
    if ($LastLines) { $Lines = Get-Content $Path -Tail $LastLines }
    else { $Lines = Get-Content $Path }
    $MatchLines = $Lines | Select-String -Pattern $Pattern
    $ActualPercent = 100 / $Lines.Count * $MatchLines.Count
    if ($ActualPercent -ge $MinPercent) { $true } else { $false }
}

Set-Alias cmtm Confirm-MatchThresholdMet
Export-ModuleMember -Function Confirm-MatchThresholdMet -Alias cmtm
