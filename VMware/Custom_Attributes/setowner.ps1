# Input array, includes all VM names from DCI that are registered.
$arrVMsInfo = Import-Csv -Path "D:\GitHub\scripts\new_owners.csv"
#Write-Output $data


## loop through all VMs listed in the CSV, setting custom attrib values for each
ForEach ($row in $arrVMsInfo) {
    ## get the VM for this row
    $vmThisOne = Get-VM -Name $row.Name
    Set-Annotation -Entity $vmThisOne -CustomAttribute "JIRA" -Value $row.JIRA
    Set-Annotation -Entity $vmThisOne -CustomAttribute "Created" -Value $row.Created
    Set-Annotation -Entity $vmThisOne -CustomAttribute "Owner" -Value $row.Owner
	Set-Annotation -Entity $vmThisOne -CustomAttribute "Project" -Value $row.project
    Set-VM -VM $vmThisOne -Notes $row.notes -confirm:$false
} ## end foreach