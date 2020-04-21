

# Add-PsSnapin VMware.VimAutomation.Core 

New-VICredentialStoreItem -Host wapvvmwvc01.prod.saasapm.com -File C:\bin\credential\shavlikpatch-service_20170912.xml `
                          -User SAASAPM\ShavlikPatch-Service -Password ''


# Server
$VIServer   = "wapvvmwvc01.prod.saasapm.com"

# Initial connection to vCenter
$cred = Get-VICredentialStoreItem -File C:\bin\credential\shavlikpatch-service_20170912.xml
Connect-VIServer -Server $VIServer -User $cred.User -Password $cred.Password

