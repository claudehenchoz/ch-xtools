## Synopsis

A collection of PowerShell tools that simplify my life and that may or may not be of use to anyone else.

## Installation

In order to install the module, open a PowerShell prompt and paste the following line (triple-click to select all of it), then press [ENTER].

    iex ((new-object net.webclient).DownloadString('https://raw.githubusercontent.com/claudehenchoz/ch-xtools/master/install-ch-xtools.ps1'))

## Features

### Get-EnterpriseModeDetails (gemd)

Gets details on Internet Explorer [Enterprise Mode](http://msdn.microsoft.com/en-us/library/dn640687.aspx) configuration. This is primarily intended to display the currently active configuration as well as the active versions.

    PS C:\> Get-EnterpriseModeDetails
    Enterprise Mode Details
    -----------------------
    Site List
    ---------
            URL (HKLM Policy):
                    http://emie.acme.com/emie.xml
            Version (Web):
                    90210
    Local
    -----
            Site List Version (HKCU):
                    90209
            Cache Folder:
                    C:\Users\Kelly\AppData\Local\Microsoft\Windows\Temporary Internet Files

### Get-EnterpriseModeSiteList (gemsl)

Get-EnterpriseModeSiteList fetches an Internet Explorer [Enterprise Mode](http://msdn.microsoft.com/en-us/library/dn640687.aspx) configuration file and displays it in a friendly, non-confusing view.

It uses the system-configured URL unless one has been specified with the -Url parameter.

    PS C:\> Get-EnterpriseModeSiteList
    Address                                                     Setting
    -------                                                     -------
    www.microsoft.com*                                          Default
    www.microsoft.com/en-us/mobile/                             Enterprise Mode
    en.wikipedia.org*                                           Default
    stallman.org*                                               edge
    en.wikipedia.org*                                           No docMode
    en.wikipedia.org/wiki/Netscape_Navigator_9*                 5

This sample was produced from the following configuration:

```xml
<rules version="90210">
  <docMode>
    <domain docMode="edge">stallman.org</domain>
    <domain>en.wikipedia.org<path docMode="5">/wiki/Netscape_Navigator_9</path></domain>
  </docMode>
  <emie>
    <domain exclude="true">www.microsoft.com<path exclude="false">/en-us/mobile/</path></domain>
    <domain exclude="true">en.wikipedia.org</domain>
  </emie>
</rules>
```
