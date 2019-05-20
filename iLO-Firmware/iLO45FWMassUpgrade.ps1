##############################################################################
#																			 #
# Script: 	Mass Upgrade HPE iLO Firmware									 #
# Date:		5/3/2019														 #
# Author:	https://github.com/rgb99										 #
# Notes:	USE WITH HPEiLOCmdlets 2.0.0.1 OR NEWER (for iLO4+)				 #
#			https://www.powershellgallery.com/packages/HPEiLOCmdlets/		 #
#																			 #
##############################################################################

# Set these variables first
#
# Latest firmware version for various iLO generations
$ilo3latest = 1.91
$ilo4latest = 2.70
$ilo5latest = 1.40
# Firmware update file location for iLO 4 and iLO 5
$ilo4FileLocation = "D:\HP\ilo4_270.bin"
$ilo5FileLocation = "D:\HP\ilo5_140.bin"

function Set-WindowTitle {
	[cmdletbinding()]
	Param (
		[Parameter(mandatory=$true)][string]$Title
	) 
	process {
		$host.ui.RawUI.WindowTitle = $Title
	}
}

function Set-TaskbarNotification {
	[cmdletbinding()]
	Param (
	[string]$Title,
	[Parameter(mandatory=$true)][string]$Message, 
	[ValidateSet("None","Info","Warning","Error")] [string]$BalloonIcon,
	[int]$TimeoutMS
	) 

	begin {
		if (!($Title)) {$Title = $host.ui.rawui.windowTitle }
		if (!($TimeoutMS)) {$TimeoutMS = 5000}
		if (!($BalloonIcon)) {$BalloonIcon = "Info"}
		[string]$IconPath='C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
		[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
	}
	process {
		$SysTrayIcon = New-Object System.Windows.Forms.NotifyIcon		
		$SysTrayIcon.BalloonTipText  = $Message
		$SysTrayIcon.BalloonTipIcon  = $BalloonIcon
		$SysTrayIcon.BalloonTipTitle = $Title
		$SysTrayIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($IconPath)
		$SysTrayIcon.Text = "Text"
		$SysTrayIcon.Visible = $True 
	}
	end {
		$SysTrayIcon.ShowBalloonTip($Timeout)
	}
}

function UpgradeiLOFirmware {
	Param (
		$iloList,
		[string]$iloFileLocation
	)
	$startTime = (Get-Date).ToString()
	Write-Host "Started at: $startTime"
	# Start stopwatch
	$StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
	# Login to all iLO devices
	$connection = $iloList | Connect-HPEiLO -Credential $credentials -DisableCertificateAuthentication -Ea SilentlyContinue -Wa SilentlyContinue
	# Upgrade all iLO device firmware
	Update-HPEiLOFirmware -Connection $connection -Location $iloFileLocation -confirm:$false -Wa SilentlyContinue -Ea SilentlyContinue | Out-Null
	# Stop stopwatch upon completion
	$StopWatch.Stop()
	$minutes = $stopWatch.Elapsed.Minutes
	$seconds = $stopWatch.Elapsed.Seconds
	Write-Host "Upgrade completed in $minutes minutes and $seconds seconds."
	# Disconnect iLO sessions before continuing
	Disconnect-HPEiLO -Connection $connection -Ea SilentlyContinue
}

Write-Host "`nChecking for HPEiLOCmdlets module..."
$moduleExists = Get-InstalledModule -Name "HPEiLOCmdlets" -MinimumVersion "2.0.0.1" -Ea SilentlyContinue
if ($moduleExists) {
	Write-Host "Module requirements met. Script proceeding..."
	$username = Read-Host -Prompt "`nEnter iLO username"
	$securepassword = Read-Host -Prompt "Enter iLO password" -AsSecureString
	$credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $username,$securepassword
	#$password = $Credentials.GetNetworkCredential().Password

	$step = 1

	$out = $null
	while ($out -ne 'yes'){
		Write-Host "`nChoose how you would like to update iLO's" -f Green
		Write-Host "(1) IP Range" -f Red
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
			$ipSearch = Read-Host -Prompt "`nEnter IP range to search for iLO's and upgrade firmware"
			Write-Host "Finding iLO IP's in specified range: $ipSearch"
			$out = Find-HPEiLO $ipSearch -Timeout 5 -Wa SilentlyContinue
			$total = $out.IP.count
			$currentDir = (Get-Location).Path
			$currentDir = $currentDir.TrimEnd('\')
			$currentTime = Get-Date -Uformat %Y%m%d%R | foreach {$_ -replace ":",""}
			$saveoutput = $currentDir+"\FoundiLO-"+$currentTime+".txt"
			Write-Host "Found $total iLO('s)... " -NoNewLine
			$list = @()
			if ($total -eq 1) {
				$list += $out.IP
			} else {
				for ($i = 0 ; $i -lt $total ; $i++) {
					$list += $out.IP[$i]
				}
				$list | Out-File -Filepath $saveoutput -Append
				Write-Host "List saved to $saveoutput" -ForegroundColor Green
			}
			
			
		}
		2 {
			$csvfile = $null
			while ($csvfile -ne 'yes'){
				$filename = Read-Host -Prompt "`nPlease specify a txt file with list of IP's (one per line)"
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

	$ilo4list = @()
	$ilo4count = 0
	$ilo5list = @()
	$ilo5count = 0

	foreach ($server in $list) {
		$findinfo = ""
		$firmware = ""
		$pn = ""	
		Write-Host "($step/$total) Checking iLO firmware for $server..."
		if (Test-Connection -ComputerName $server -Count 2 -Delay 1 -TimeToLive 255 -BufferSize 256 -ThrottleLimit 32 -Ea 0) {
			Set-WindowTitle -Title "iLO45FWMassUpgrade - ($step/$total) Checking $server..."
			$findinfo = Find-HPEiLO $server -Wa SilentlyContinue
			$firmware = ($findinfo).FWRI
			$pn = ($findinfo).PN
			if ($pn -like "*iLO 3*" -and $firmware -lt $ilo3latest) {
				Write-Host "`t$pn firmware is out-of-date. (Detected = " -NoNewLine
				Write-Host "$firmware" -ForegroundColor Red -NoNewLine
				Write-Host ")"
				Write-Host " `tThis script can only upgrade iLO 4 or newer. Please upgrade through other methods!" -ForegroundColor Yellow
			} elseif ($pn -like "*iLO 4*" -and $firmware -lt $ilo4latest) {
				$ilo4list += $findinfo
				$ilo4count++
				Write-Host "`t$pn firmware is out-of-date. (Detected = " -NoNewLine
				Write-Host "$firmware" -ForegroundColor Red -NoNewLine
				Write-Host ")"
			} elseif ($pn -like "*iLO 5*" -and $firmware -lt $ilo5latest) {
				$ilo5list += $findinfo
				$ilo5count++
				Write-Host "`t$pn firmware is out-of-date. (Detected = " -NoNewLine
				Write-Host "$firmware" -ForegroundColor Red -NoNewLine
				Write-Host ")"
			} else {
				Write-Host "`t$pn firmware is up-of-date."
			}
		}
		$step += 1
	}

	# Start iLO 4 firmware update

	Write-Host "`n"
	if ($ilo4list.count -eq 0) {
		Write-Host "All iLO 4 devices, if detected, are up-to-date.`n"
	} else {
		Write-Host "Upgrading $ilo4count out-of-date iLO 4 firmware devices... (this may take up to 15 minutes)"
		Set-WindowTitle -Title "Upgrading ilO 4 firmware"
		UpgradeiLOFirmware $ilo4list $ilo4FileLocation
	}

	# Start iLO 5 firmware update

	if ($ilo5list.count -eq 0) {
		Write-Host "`nAll iLO 5 devices, if detected, are up-to-date.`n"
	} else {
		Write-Host "`nUpgrading $ilo5count out-of-date iLO 5 firmware devices... (this may take up to 15 minutes)"
		Set-WindowTitle -Title "Upgrading ilO 5 firmware"
		UpgradeiLOFirmware $ilo5list $ilo5FileLocation
	}
} else {
	Write-Host "Module HPEiLOCmdlets is not loaded or does not meet the minimum version requirement (2.0.0.1)" -ForegroundColor Red
	Write-Host "Exiting script..."
}

Set-WindowTitle -Title "Administrator: Windows PowerShell"
Set-TaskbarNotification -Message "iLOFWupgrade Completed"