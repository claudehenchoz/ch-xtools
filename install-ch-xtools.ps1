$url = "https://raw.githubusercontent.com/claudehenchoz/ch-xtools/master/ch-xtools.psm1"
$chxtoolspath = [environment]::getfolderpath("mydocuments") + "\WindowsPowerShell\Modules\ch-xtools"
if (!(Test-Path $chxtoolspath)) { New-Item -itemtype "Directory" $chxtoolspath -force | Out-Null }
Invoke-WebRequest $url -OutFile "$chxtoolspath\ch-xtools.psm1" 
Write-Output "Done. Please (re-) start PowerShell."
