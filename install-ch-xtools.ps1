# URL to .psm1 file
$url = "https://raw.githubusercontent.com/claudehenchoz/ch-xtools/master/ch-xtools.psm1"

# File name of URL without extension
$modname = (([System.Uri]"$url").Segments[-1]).Split(".")[0]

# Create local module path
$modpath = [environment]::getfolderpath("mydocuments") + `
               "\WindowsPowerShell\Modules\$modname"

# Create module folder(s) if it doesn't exist
if (!(Test-Path $modpath)) {
    New-Item -itemtype "Directory" $modpath -force | Out-Null
}

# Download module
Invoke-WebRequest $url -OutFile "$modpath\$modname.psm1"

# Import so it becomes immediately loaded
Import-Module "$modpath\$modname.psm1"
Write-Output "Done. Run `"gcm -m $modname`" to get a list of tools."
