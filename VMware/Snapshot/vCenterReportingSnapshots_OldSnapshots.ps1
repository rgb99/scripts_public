# Script:
# vCenterReportingSnapshots_OldSnapshots
# 
# Purpose:
# Find all snapshots in the specified vCenter instance and report
#
# Script Server:
# util22insm.win.keynote.com
# 
# Frequency:
# Triggered every X minutes from a Windows Scheduled Task
# 
# 
# Revisions:
# 
#      Rev1 - 2015-07-13
#      Initial implementation.
# 
#      Rev2 - 2016-01-13
#      Changed to old snapshots.
# 

#  ----------------
#  Local log format
#   
#  Mon Feb 2 22:07:20 2015 errorlevel=INFO message=Example message
#  ----------------



# Logging for current script (needs C:\bin\Snapshot\CommonPowerShellFunctions.ps1)

$scriptlogdir                        = "C:\bin\Snapshot\Logs\vCenterReportingSnapshots_OldSnapshots"
$scriptlogdirretention               = "30"

. C:\bin\Snapshot\CommonPowerShellFunctions.ps1

# End of logging for current script


# Custom HTML output for Title and Precontent
$hf = $hf + @"
<title>
vCenter Snapshot Report - SysEng - $CurDate
</title>
"@

$Pre = "<span style='font-size: 18pt'>vCenter Snapshot Report - SysEng</span><br/><br/>Run on " + $CurDateFriendly + "<br/><br/>"

# End of custom HTML output


# -------------------------------------------------------------------------------------------------------------------
# 
# Current Script - Parameters
# 
# -------------------------------------------------------------------------------------------------------------------


# Script parameters not defined in function parameters

$EmlRecip                       = "OPSSystemsEngineering@dynatrace.com"    # "OPSSystemsEngineering@dynatrace.com"
$EmlSender                      = "WAPVVMWAT01 <no-reply@dynatrace.com>"
$SmtpServer                     = "prodrelay.saasapm.com"
$VIServer                       = "wapvvmwvc01.prod.saasapm.com"
$date_threshold                 = (Get-Date).AddDays(-20)
$datacenter                     = "DC3 Prod"

# Add VMware PsSnapin
# Add-PsSnapin VMware.VimAutomation.Core #-ea "SilentlyContinue"

# -------------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------------
# -------------------------------------------------------------------------------------------------------------------


# -------------------------------------------------------------------------------------------------------------------
# 
# Current Script - Main Logic
# 
# -------------------------------------------------------------------------------------------------------------------

# Initial connection to vCenter
$Credential = Get-VICredentialStoreItem -Host wapvvmwvc01.prod.saasapm.com -File C:\bin\credential\shavlikpatch-service_20170912.xml
#Use the $Credentials variable for the username and password switches in the Connect-VIServer
if (Connect-VIServer $VIServer -User $Credential.User -Password $Credential.Password)
{
# Add queried clusters to html output
$Pre = $Pre + "VM's in DC3 Prod<br/>"

# Query vCenter for initial data and objects
$colSnapsRaw = Get-Datacenter $datacenter | Get-VM | Get-Snapshot

# Initialize arrays
$objSnapTemp=@()
$colSnapshots=@()
$colSnapshotsCritical=@()

# Iterate through objects and pull out information
foreach ($objSnap in $colSnapsRaw)
    {
    $vm=$objSnap.VM.Name.ToString()
    $name=$objSnap.Name.ToString()
	$description=$objSnap.Description.ToString()
    $size=[math]::round($objSnap.SizeGB,2)
    $date=$objSnap.Created.ToString()
    $snap_date_time=$objSnap.Created
    
    $objSnapTemp = New-Object PSCustomObject
        $objSnapTemp | Add-Member -type NoteProperty -name 'VirtualMachine' -value $vm
        $objSnapTemp | Add-Member -type NoteProperty -name 'Snapshot' -value $name
		$objSnapTemp | Add-Member -type NoteProperty -name 'Description' -value $description
        $objSnapTemp | Add-Member -type NoteProperty -name 'SizeGB' -value $size
        $objSnapTemp | Add-Member -type NoteProperty -name 'Created' -value $date
    
    If ($snap_date_time -gt $date_threshold)
        {
        # Add to a collection for normal reporting
        $colSnapshots += $objSnapTemp
    } Else {
        # Add to a collection for critical reporting
        $colSnapshotsCritical += $objSnapTemp
        }  
    } # End of foreach ($objSnap in $colSnapsRaw)
    


# Finalize HTML output after $VMClusters | foreach loop
$Pre = $Pre + "<br/>"

# Final steps for $colSnapshots
if ($colSnapshots.Count -gt 0)
    {
    # Output table for viewing
    Write-Host "`n`n----------------- Newer Snapshots -----------------"
    $colSnapshots | Format-Table

    # Formatting
    $htmloutput = $colSnapshots | Sort-Object -Property VirtualMachine  | ConvertTo-Html -Head $hf -PreContent $Pre | Set-AlternatingRows -CSSEvenClass even -CSSOddClass odd
    
    # Deliver report
    LogData -lvl "INFO" -msg "Report created and emailed to: $EmlRecip"
    EmailNotify -subject "DC3 Prod Snapshots - Report" -body ($htmloutput | Out-String) -html "True"

    # Optional output to a directory
    $LogDate = Get-Date -format "yyyyMMdd"
    $htmloutput | Out-File $scriptlogdir\htmloutput_$LogDate.html  
    } 
Else
    {
    # Indicate no results in logs and email
    LogData -lvl "INFO" -msg "No normal snapshots found."
    EmailNotify -subject "DC3 Prod Snapshots - Report" -body "No normal snapshots found."   
    
    } # End of if ($colSnapshots.Count -gt 0)



# Final steps for $colSnapshotsCritical
if ($colSnapshotsCritical.Count -gt 0)
    {
    # Output table for viewing
    Write-Host "`n`n----------------- Older Snapshots -----------------"
    $colSnapshotsCritical | Format-Table

    # Change header background to red color
    $hf = $hf -replace "#00b5d8","#FF0000"

    # Formatting
    $htmloutput = $colSnapshotsCritical | Sort-Object -Property VirtualMachine  | ConvertTo-Html -Head $hf -PreContent $Pre | Set-AlternatingRows -CSSEvenClass even -CSSOddClass odd
    
    # Deliver report
    LogData -lvl "WARNING" -msg "Critical report created and emailed to: $EmlRecip"
    EmailNotify -subject "DC3 Prod Snapshots - Old Snapshots (Critical)" -body ($htmloutput | Out-String) -html "True" -priority "High"

    # Optional output to a directory
    $LogDate = Get-Date -format "yyyyMMdd"
    $htmloutput | Out-File $scriptlogdir\htmloutput_critical_$LogDate.html  
    } 
Else
    {
    # Indicate no results in logs and email
    LogData -lvl "INFO" -msg "No critical snapshots found older than $date_threshold."

    } # End of if ($colSnapshotsCritical.Count -gt 0)

# Disconnect from vCenter
Disconnect-VIServer -Confirm:$False
}
else {
	Write-Host "Could not connect to vCenter"
}