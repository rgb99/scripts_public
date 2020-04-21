###############################################################################
#									iLO Settings				 	  		  #
#				USE WITH HPEiLOCmdlets 2.0.0.1 OR NEWER	(for iLO4+)			  #
#		     https://www.powershellgallery.com/packages/HPEBIOSCmdlets/		  #
###############################################################################
#
#	Used primarily on iLO v4
#
#	Author: Robert Baranauskas
#	Date: 2018-09-13
#
# 2018-09-26:	Updated to include iLO3 settings.
# 2019-03-12:	Updated to include iLO3 1.91 firmware update
# 2019-03-15:	Added UpgradeFirmware function to shorten code length
# 2019-04-02:	Updated to include iLO4 2.62 firmware update
# 2019-04-12:	Removed iLO firmware update code
#				Removed iLO3 code
# 2020-01-27:	Removed site-specific settings so I could release this publicly on GitHub
#				Set your custom variables at Line 178


Write-Host "`nChecking for HPEiLOCmdlets module..."
$moduleExists = Get-InstalledModule -Name "HPEiLOCmdlets" -MinimumVersion "2.0.0.1" -Ea SilentlyContinue
if ($moduleExists) {
	Write-Host "Module requirements met. Script proceeding..."
	$username = Read-Host -Prompt "`nEnter iLO username"
	$securepassword = Read-Host -Prompt "Enter iLO password" -AsSecureString
	$credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $username,$securepassword
	$password = $Credentials.GetNetworkCredential().Password

	$step = 1

	$out = $null
	while ($out -ne 'yes'){
		Write-Host "Choose how you would like to find and update iLO settings" -f Green
		Write-Host "(1) IP Range or iLO Hostname" -f Red
		Write-Host "(2) Specify a txt file" -f Red
		Write-Host "Choose a method (type the number)" -nonewline -f Yellow
		$choice = Read-Host " "
		if($choice -eq '1' -or $choice -eq '2'){
			$out = 'yes'
		} else {
			Write-Host "PLEASE PROVIDE AN APPROPRIATE RESPONSE" -f Red `n
		}
	}

	switch($choice){
		1 {
			$ipSearch = Read-Host -Prompt "`nEnter IP range or iLO Hostname to search for iLO's"
			Write-Host "Finding iLO IP's in specified range: $ipSearch"
			$out = Find-HPEiLO $ipSearch -Timeout 5 -Wa SilentlyContinue
			$total = $out.IP.count
			Write-Host "Found $total iLO('s)...."
			$list = @()
			if ($total -eq 1) {
				$list += $out.IP
			} else {
				for ($i = 0 ; $i -lt $total ; $i++) {
					$list += $out.IP[$i]
				}
			}
		}
		2 {
			$csvfile = $null
			while ($csvfile -ne 'yes'){
				$filename = Read-Host -Prompt "`nPlease specify a txt file with list of IP's or iLO hostnames (one per line)"
				if ($filename.EndsWith("txt")){
					$csvfile = 'yes'
				} else {
					Write-Host "File not found. Try again."
				}
			}
			$fexists = Test-Path $filename
			if ($fexists) {
				Write-Host "File is valid. Gathering information... " -NoNewLine
				$list = Get-Content "$filename"
				$total = $list.count
				Write-Host "File has $total entries`n"
			}
		}
	}

	foreach ($server in $list) {
		Write-Host "`n($step/$total) Connecting to $server..."
		$connection = Connect-HPEiLO $server -Username $username -Password $password -DisableCertificateAuthentication -Wa SilentlyContinue
		if ($null -ne $connection) {				
			Write-Host "`n`tiLO Host Settings" -ForegroundColor Yellow
			# Detect iLO Host Name
			$detectediLO_hn = (Get-HPEiLOIPv4NetworkSetting -connection $connection).DNSname
			Write-Host "`tiLO Hostname detected as:`t" -NoNewLine -ForegroundColor DarkCyan
			Write-Host "$detectediLO_hn" -ForegroundColor Cyan
			
			# Detect Server Name
			$detectedSN = (Get-HPEiLOAccessSetting -connection $connection).ServerName
			Write-Host "`tServer Name detected as:`t" -NoNewLine -ForegroundColor DarkCyan
			Write-Host "$detectedSN" -ForegroundColor Cyan
			
			# Detect Server FQDN
			$detectedServerFQDN = (Get-HPEiLOAccessSetting -connection $connection).ServerFQDN
			Write-Host "`tServer FQDN detected as:`t"-NoNewLine -ForegroundColor DarkCyan
			Write-Host "$detectedServerFQDN" -ForegroundColor Cyan
			
			# Prompt user if they wish to update the iLO hostname
			$iLO_hn_input = Read-Host -Prompt "`tDo you want to change the iLO host name (y/n)?"
			while ($iLO_hn_input -ne "y" -and $iLO_hn_input -ne "n") {
				$iLO_hn_input = Read-Host -Prompt "`tPlease choose 'y' or 'n'"
			} 
			if ($iLO_hn_input -eq "y") {
				$newiLO_hn = Read-Host -Prompt "`tEnter new iLO host name"
			} elseif ($iLO_hn_input -eq "n") {
				$newiLO_hn = $detectediLO_hn
			}
			
			# Prompt user if they wish to update the server name
			$iLO_sn_input = Read-Host -Prompt "`tDo you want to change the server name (y/n)?"
			while ($iLO_sn_input -ne "y" -and $iLO_sn_input -ne "n") {
				$iLO_sn_input = Read-Host -Prompt "`tPlease choose 'y' or 'n'"
			} 
			if ($iLO_sn_input -eq "y") {
				$newSN = Read-Host -Prompt "`tEnter new server name"
			} elseif ($iLO_sn_input -eq "n") {
				$shortSN = $detectedSN -split "\."
				$newSN = $shortSN[0].ToLower()
			}
				
			# Check SNMP settings
			# Display current SNMP settings.
			Write-Host "`n`tSNMP Settings" -ForegroundColor Yellow
			$detectedSystemLocation = (Get-HPEiLOSNMPSetting -connection $connection).SystemLocation
			Write-Host "`tSystem Location detected as: " -NoNewLine -ForegroundColor DarkCyan
			Write-Host "$detectedSystemLocation" -ForegroundColor Cyan
			$detectedSystemRole = (Get-HPEiLOSNMPSetting -connection $connection).SystemRole
			Write-Host "`tSystem Role detected as: " -NoNewLine -ForegroundColor DarkCyan
			Write-Host "$detectedSystemRole" -ForegroundColor Cyan
			$detectedSystemRoleDetail = (Get-HPEiLOSNMPSetting -connection $connection).SystemRoleDetail
			Write-Host "`tSystem Role Detail detected as: " -NoNewLine -ForegroundColor DarkCyan
			Write-Host "$detectedSystemRoleDetail" -ForegroundColor Cyan
			
			# Prompt user if they wish to update System Location	
			$SNMPSystemLocationInput = Read-Host -Prompt "`tDo you want to change the System Location (y/n)?"
			while ($SNMPSystemLocationInput -ne "y" -and $SNMPSystemLocationInput -ne "n") {
				$SNMPSystemLocationInput = Read-Host -Prompt "`tPlease choose 'y' or 'n'"
			} 
			if ($SNMPSystemLocationInput -eq "y") {
				$newSystemLocation = Read-Host -Prompt "`tEnter new System Location value"
			} elseif ($SNMPSystemLocationInput -eq "n") {
				$newSystemLocation = $detectedSystemLocation
			}
			
			# Prompt user if they wish to update System Role	
			$SNMPSystemRoleInput = Read-Host -Prompt "`tDo you want to change the System Role (y/n)?"
			while ($SNMPSystemRoleInput -ne "y" -and $SNMPSystemRoleInput -ne "n") {
				$SNMPSystemRoleInput = Read-Host -Prompt "`tPlease choose 'y' or 'n'"
			} 
			if ($SNMPSystemRoleInput -eq "y") {
				$newSystemRole = Read-Host -Prompt "`tEnter new System Role value"
			} elseif ($SNMPSystemRoleInput -eq "n") {
				$newSystemRole = $detectedSystemRole
			}
			
			# Prompt user if they wish to update System Role Detail	
			$SNMPSystemRoleDetailInput = Read-Host -Prompt "`tDo you want to change the System Role Detail (y/n)?"
			while ($SNMPSystemRoleDetailInput -ne "y" -and $SNMPSystemRoleDetailInput -ne "n") {
				$SNMPSystemRoleDetailInput = Read-Host -Prompt "`tPlease choose 'y' or 'n'"
			} 
			if ($SNMPSystemRoleDetailInput -eq "y") {
				$newSystemRoleDetail = Read-Host -Prompt "`tEnter new System Role Detail value"
			} elseif ($SNMPSystemRoleDetailInput -eq "n") {
				$newSystemRoleDetail = $detectedSystemRoleDetail
			}
			
			# Prompt user if they wish to make changes or not
			$makechange = Read-Host -Prompt "`n`tContinue to make changes to iLO settings (y/n)?"
			while ($makechange -ne "y" -and $makechange -ne "n") {
				$makechange = Read-Host -Prompt "`tPlease choose 'y' or 'n'"
			} 
			if ($makechange -eq "y") {
				# Create variables
				# AlertMail
				$AlertMailSMTPServer = "smtp.relay.com"
				$AlertMailEmail = "user@domain.com"
				$AlertMailPort = "25"
				$AlertMailDomain = "domain.com"
				# Syslog
				$RemoteSyslogPort = "514"
				$RemoteSyslogServer = "1.2.3.4"
				# iLO Admin User
				$iLOUserName = "tempadmin"
				$iLOUserPw = "temppass"
				# Misc
				$newServerFQDN = $newSN + ".domain.com"
				$DomainName = "domain.com"
				# SNMP
				$SNMPSystemContact = "System Contact"
				# WINS Servers
				$WINSServerTypes = ,@("Primary","Secondary")
				$WINSServers = ,@("0.0.0.0", "0.0.0.0")
				# License Key
				$LicenseKey = "00000-00000-00000-00000-00000"
				# Directory Group
				$NewGroupName = "CN=group,OU=Folder,OU=Folder2,DC=domain,DC=com"
				$GroupSID = "get_group_SID_from_AD_attributes"
				# Directory Settings
				$index = ,@(1,2)
				$value = ,@("OU=GroupsFolder,OU=Folder,DC=domain,DC=com","OU=UsersFolder,OU=Folder,DC=domain,DC=com")
				$DirectoryServerAddress = ""
				$DirectoryServerPort = "636"
				# SNTP
				$SntpServers = ,@("ntp1.domain.com","ntp2.domain.com")
				$SNTPTimeZone = "Atlantic/Reykjavik"
				# DNS Servers
				$DNSServerTypes = ,@("Primary","Secondary","Tertiary")
				$DNSServers = ,@("1.2.3.4", "1.2.3.5", "1.2.3.6")		
				
				# Make Changes
				Write-Host "`n`tMaking Changes" -ForegroundColor Yellow
					
				# Apply iLO Advanced License Key
				Write-Host "`tApplying iLO Advanced license key... " -NoNewLine
				Set-HPEiLOLicense -connection $connection -Key $LicenseKey -Wa SilentlyContinue
				Write-Host "DONE!" -ForegroundColor Green	
				
				<#
				Uncomment if you wish add a new Admin user

				# Apply Administration > User Adminstration Settings
				Write-Host "`tApplying User settings... " -NoNewLine
				$tempadminExist = $false
				$userList = Get-HPEiLOUser -Connection $connection
				for ($i=0 ; $i -lt $userList.UserInformation.Count ; $i++) {
					if ($userList[0].UserInformation[$i].LoginName -match "tempadmin") {
						$tempadminExist = $true
					}
				}
				if ($tempadminExist -eq $true) {
					Write-Host "User 'tempadmin' already exists" -ForegroundColor Green
				} else {
					Add-HPEiLOUser -Connection $connection `
						-Username $iLOUserName -Password $iLOUserPw `
						-LoginName $iLOUserName `
						-UserConfigPrivilege Yes -iLOConfigPrivilege Yes -RemoteConsolePrivilege Yes `
						-VirtualMediaPrivilege Yes -VirtualPowerAndResetPrivilege Yes | Out-Null
					Write-Host "DONE!" -ForegroundColor Green
				}
				#>
				
				# Add Directory Group
				Write-Host "`tApplying Directory Group settings... " -NoNewLine
				Add-HPEiLODirectoryGroup -Connection $connection `
					-GroupName $NewGroupName `
					-GroupSID $GroupSID `
					-UserConfigPrivilege Yes `
					-iLOConfigPrivilege Yes `
					-RemoteConsolePrivilege Yes `
					-VirtualMediaPrivilege Yes `
					-VirtualPowerAndResetPrivilege Yes `
					-LoginPrivilege Yes -Wa SilentlyContinue -Ea SilentlyContinue | Out-Null
				Write-Host "DONE!" -ForegroundColor Green				
				
				# Set Administration > Security > Directory settings
				Write-Host "`tApplying Directory settings... " -NoNewLine
				Set-HPEiLODirectorySetting -connection $connection `
					-LDAPDirectoryAuthentication DirectoryDefaultSchema `
					-LocalUserAccountEnabled Yes `
					-DirectoryServerAddress $DirectoryServerAddress `
					-DirectoryServerPort $DirectoryServerPort `
					-UserContextIndex $index `
					-UserContext $value -Wa SilentlyContinue
				Write-Host "DONE!" -ForegroundColor Green
				
				# Set SNMP Settings
				Write-Host "`tApplying SNMP Settings... " -NoNewLine
				Set-HPEiLOSNMPSetting -connection $connection `
					-SystemLocation $newSystemLocation `
					-SystemContact $SNMPSystemContact `
					-SystemRole $newSystemRole `
					-SystemRoleDetail $newSystemRoleDetail `
					-ReadCommunity1 "" `
					-ReadCommunity2 ""
				Set-HPEiLOSNMPAlertDestination -connection $connection -ID 1 -AlertDestination "" -TrapCommunity "" -TrapCommunityVersion 1
				Set-HPEiLOSNMPAlertDestination -connection $connection -ID 2 -AlertDestination "" -TrapCommunity "" -TrapCommunityVersion 1
				Set-HPEiLOSNMPAlertDestination -connection $connection -ID 3 -AlertDestination ""
				Write-Host "DONE!" -ForegroundColor Green
							
				# Set Administration > Security > HPE SSO settings
				Write-Host "`tApplying HPE SSO settings... " -NoNewLine
				Set-HPEiLOSSOSetting -connection $connection `
					-TrustMode TrustbyCertificate `
					-UserRoleUserConfigPrivilege No -UserRoleRemoteConsolePrivilege No -UserRoleVirtualPowerAndResetPrivilege No `
					-UserRoleVirtualMediaPrivilege No -UserRoleiLOConfigPrivilege No `
					-OperatorRoleUserConfigPrivilege No -OperatorRoleRemoteConsolePrivilege Yes -OperatorRoleVirtualPowerAndResetPrivilege Yes `
					-OperatorRoleVirtualMediaPrivilege Yes -OperatorRoleiLOConfigPrivilege No `
					-AdministratorRoleUserConfigPrivilege Yes -AdministratorRoleRemoteConsolePrivilege Yes -AdministratorRoleVirtualPowerAndResetPrivilege Yes `
					-AdministratorRoleVirtualMediaPrivilege Yes -AdministratorRoleiLOConfigPrivilege Yes `
					-Wa SilentlyContinue
				Write-Host "DONE!" -ForegroundColor Green
					
				# Apply Administration > Management > AlertMail settings
				Write-Host "`tApplying AlertMail settings... " -NoNewLine					
				Set-HPEiLOAlertMailSetting -Connection $connection `
					-AlertMailEmail $AlertMailEmail `
					-AlertMailEnabled Yes `
					-AlertMailSenderDomain $AlertMailDomain `
					-AlertMailSMTPPort $AlertMailPort `
					-AlertMailSMTPServer $AlertMailSMTPServer -Wa SilentlyContinue
				Write-Host "DONE!" -ForegroundColor Green
				
				# Apply Administration > Management > Remote Syslog settings	
				Write-Host "`tApplying Remote Syslog settings... " -NoNewLine
				Set-HPEiLORemoteSyslog -connection $connection `
					-RemoteSyslogEnabled Yes `
					-RemoteSyslogServer $RemoteSyslogServer `
					-RemoteSyslogPort $RemoteSyslogPort -Wa SilentlyContinue
				Write-Host "DONE!" -ForegroundColor Green

				# Apply Network > iLO Dedicated Network > General settings
				Write-Host "`tApplying server name and server FQDN settings... " -NoNewLine
				Set-HPEiLOAccessSetting -connection $connection -ServerFQDN $newServerFQDN -ServerName $newSN
				Write-Host "DONE!" -ForegroundColor Green
				
				# Apply Power Management > Power Settings setting
				Write-Host "`tApplying Power Regulator settings... " -NoNewLine
				Set-HPEiLOPowerRegulatorSetting -connection $connection -Mode Max -Wa SilentlyContinue
				Write-Host "DONE!" -ForegroundColor Green
				
				# Apply Network > iLO Dedicated Network Port settings
				Write-Host "`tApplying iLO IPv4 network configuration... " -NoNewLine			
				Set-HPEiLOIPv4NetworkSetting -connection $connection `
					-InterfaceType Dedicated `
					-DHCPv4NTPServer Disabled `
					-DHCPv4DNSServer Disabled `
					-DHCPv4DomainName Disabled `
					-DHCPv4WINSServer Disabled `
					-DHCPv4StaticRoute Disabled `
					-DNSName $newiLO_hn.toLower() `
					-RegisterDDNSServer Enabled `
					-DomainName $DomainName `
					-WINSServerType $WINSServerTypes `
					-WINSServer $WINSServers `
					-RegisterWINSServer Disabled `
					-DNSServerType $DNSServerTypes `
					-DNSServer $DNSServers -Wa SilentlyContinue | Out-Null
				Write-Host "DONE!" -ForegroundColor Green
				Write-Host "`tApplying iLO IPv6 network configuration... " -NoNewLine
				Set-HPEiLOIPv6NetworkSetting -connection $connection `
					-InterfaceType Dedicated `
					-PreferredProtocol Disabled `
					-StatelessAddressAutoConfiguration Disabled `
					-DHCPv6StatefulMode Disabled `
					-DHCPv6SNTPSetting Disabled `
					-DHCPv6DNSServer Disabled `
					-DHCPv6StatelessMode Disabled `
					-RegisterDDNSServer Disabled -Wa SilentlyContinue | Out-Null
				Write-Host "DONE!" -ForegroundColor Green

				
				# Apply Network > iLO Dedicated Network Port > SNTP
				Write-Host "`tApplying SNTP settings... " -NoNewline
				Set-HPEiLOSNTPSetting -Connection $connection `
					-DHCPv4NTPServer Disabled `
					-DHCPv6NTPServer Disabled `
					-PropagateTimetoHost Disabled `
					-Timezone $SNTPTimeZone `
					-SNTPServer $SntpServers | Out-Null
				Write-Host "DONE!" -ForegroundColor Green	
			} elseif ($makechange -eq "n") {
				Write-Host "`n`tSkipping $server" -ForegroundColor Magenta
			}
		} else {
			Write-Host  "Could not login with provided credentials." -ForegroundColor Red
		}
		$step++
	} 
} else {
	Write-Host "Module HPEiLOCmdlets is not loaded or does not meet the minimum version requirement (2.0.0.1)" -ForegroundColor Red
	Write-Host "Exiting script..."
}
Write-Host "`n"