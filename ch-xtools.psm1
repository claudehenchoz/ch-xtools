function Format-FileSize {
    # Used by Get-FolderSizes to return a human-readable size representation
    Param ([long]$Size)
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
