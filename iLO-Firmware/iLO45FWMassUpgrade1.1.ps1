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
$ilo4latest = 2.72
$ilo5latest = 2.10
# Firmware update file location for iLO 4 and iLO 5
$ilo4FileLocation = "D:\HP\ilo4_272.bin"
$ilo5FileLocation = "D:\HP\ilo5_210_SHA512.bin"

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
    Write-Host "Started at:     $startTime" -ForegroundColor Yellow
	# Start stopwatch
	$StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
	# Login to all iLO devices
	$connection = $iloList | Connect-HPEiLO -Credential $credentials -DisableCertificateAuthentication -Ea SilentlyContinue -Wa SilentlyContinue
	if ($null -ne $connection) {
		# Upgrade all iLO device firmware
		Update-HPEiLOFirmware -Connection $connection -Location $iloFileLocation -confirm:$false -Wa SilentlyContinue -Ea SilentlyContinue | Out-Null
		# Disconnect iLO sessions before continuing
        Disconnect-HPEiLO -Connection $connection -Ea SilentlyContinue
        $global:badlogin = $false
	} else {
        Write-Host "ERROR: Could not login to any device(s)" -ForegroundColor Red
        $global:badlogin = $true
	}
	# Stop stopwatch upon completion
	$StopWatch.Stop()
	$minutes = $stopWatch.Elapsed.Minutes
    $seconds = $stopWatch.Elapsed.Seconds
    $endTime = (Get-Date).ToString()
	Write-Host "Completed at:   $endTime" -ForegroundColor Yellow
	Write-Host "Task completed in $minutes minutes and $seconds seconds." -ForegroundColor Yellow
	Set-WindowTitle -Title "Administrator: Windows PowerShell"
}

function VerifyiLOFirmware {
    Param (
        $iloIPlist
    )
    Write-Host "`nVerifying upgrades, please wait..." -ForegroundColor Cyan
    $currentDir = (Get-Location).Path
	$currentDir = $currentDir.TrimEnd('\')
	$currentTime = Get-Date -Uformat %Y%m%d%R | foreach {$_ -replace ":",""}
	$saveoutput = $currentDir+"\iLO-FailedUpgrade-"+$currentTime+".csv"
    for ($i = 0; $i -lt $iloIPlist.count; $i++) {
        $server = $iloIPlist[$i]
        Write-Progress -Activity "Verifying Upgrades..." -status "Checking $server" -percentComplete ($i / $iloIPlist.count*100)
        if (Test-Connection -ComputerName $server -Count 2 -Delay 1 -TimeToLive 255 -BufferSize 256 -ThrottleLimit 32 -Ea 0) {
            $findinfo = Find-HPEiLO $server -Wa SilentlyContinue
            $firmware = ($findinfo).FWRI
            $pn = ($findinfo).PN
            if ($pn -like "*iLO 4*" -and $firmware -lt $ilo4latest) {
                $findinfo | Export-Csv -Path $saveoutput -Append
                Write-Host "$server is still version $firmware" -ForegroundColor Red
            } elseif ($pn -like "*iLO 5*" -and $firmware -lt $ilo5latest) {
                $findinfo | Export-Csv -Path $saveoutput -Append
                Write-Host "$server is still version $firmware" -ForegroundColor Red
            }
        } else {
            Write-Host "$server cannot be reached." -ForegroundColor Red
        }
    }
    $checkFailedFileExists = Test-Path $saveoutput
    if ($checkFailedFileExists -eq $true ) {
        Write-Host "`nFailed iLO firmware upgrade info saved to $saveoutput`n" -ForegroundColor Yellow
    } else {
        Write-Host "`nAll upgrades completed successfully.`n" -ForegroundColor Green
    }
}

Write-Host "`nChecking for HPEiLOCmdlets module..."
$moduleExists = Get-InstalledModule -Name "HPEiLOCmdlets" -MinimumVersion "2.0.0.1" -Ea SilentlyContinue
if ($moduleExists) {
	Write-Host "Module requirements met. Script proceeding..."
	$username = Read-Host -Prompt "`nEnter iLO username"
	$securepassword = Read-Host -Prompt "Enter iLO password" -AsSecureString
	$credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $username,$securepassword

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
			$out = Find-HPEiLO $ipSearch -Timeout 10 -Wa SilentlyContinue
			$total = $out.IP.count
			$currentDir = (Get-Location).Path
			$currentDir = $currentDir.TrimEnd('\')
			$currentTime = Get-Date -Uformat %Y%m%d%R | foreach {$_ -replace ":",""}
			$saveoutput = $currentDir+"\iLO-Found-"+$currentTime+".txt"
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
				Write-Host "File is valid. Gathering information... " -NoNewLine -ForegroundColor Cyan
				$list = Get-Content "$filename"
				$total = $list.count
				Write-Host "File has $total entries`n" -ForegroundColor Cyan
			}
		}
	}

	# Create empty arrays and counter for iLO device info
    $ilo4list = @()
	$ilo4count = 0
    $ilo5list = @()
    $ilo5count = 0
    $iloIPlist = @()
    $errorlist = @()

	# Get unique values for saved iLO information data
	$currentDir = (Get-Location).Path
	$currentDir = $currentDir.TrimEnd('\')
	$currentTime = Get-Date -Uformat %Y%m%d%R | foreach {$_ -replace ":",""}
	$saveoutput = $currentDir+"\iLO-Info-"+$currentTime+".csv"

	foreach ($server in $list) {
		$findinfo = ""
		$firmware = ""
		$pn = ""	
		Write-Host "($step/$total) Checking iLO firmware for $server..."
		if (Test-Connection -ComputerName $server -Count 2 -Delay 1 -TimeToLive 255 -BufferSize 256 -ThrottleLimit 32 -Ea 0) {
			Set-WindowTitle -Title "iLO45FWMassUpgrade - ($step/$total) Checking $server..."
			$findinfo = Find-HPEiLO $server -Wa SilentlyContinue
			$findinfo | Export-Csv -Path $saveoutput -Append
			$firmware = ($findinfo).FWRI
			$pn = ($findinfo).PN
			if ($pn -like "*iLO 3*" -and $firmware -lt $ilo3latest) {
				Write-Host "`t$pn firmware is out-of-date. (Detected = $firmware)"
				Write-Host "`tThis script can only upgrade iLO 4 or newer. Please upgrade through other methods!" -ForegroundColor Yellow
			} elseif ($pn -like "*iLO 4*" -and $firmware -lt $ilo4latest) {
				$ilo4list += $findinfo
                $ilo4count++
                $iloIPlist += $findinfo.IP
				Write-Host "`t$pn firmware will be upgraded from $firmware."
			} elseif ($pn -like "*iLO 5*" -and $firmware -lt $ilo5latest) {
				$ilo5list += $findinfo
                $ilo5count++
                $iloIPlist += $findinfo.IP
				Write-Host "`t$pn firmware will be upgraded from $firmware."
			} elseif ($null -eq $pn) {
                Write-Host "`tERROR: Could not gather info" -ForegroundColor Red
                $errorlist += $server
			} else {
                Write-Host "`t$pn firmware is up-of-date."
            }
		} else {
            Write-Host "`tERROR: $server cannot be reached" -ForegroundColor Red
            $errorlist += $server
        }
		$step += 1
	}

	Write-Host "`niLO informated saved to $saveoutput" -ForegroundColor Green

	# Start iLO 4 firmware update

	Write-Host "`n"
	if ($ilo4list.count -eq 0) {
		Write-Host "All iLO 4 devices, if detected, are up-to-date.`n" -ForegroundColor Green
	} else {
		Write-Host "Upgrading $ilo4count out-of-date iLO 4 firmware devices... (this may take up to 15 minutes)" -ForegroundColor Cyan
		Set-WindowTitle -Title "Upgrading ilO 4 firmware"
        UpgradeiLOFirmware $ilo4list $ilo4FileLocation
	}

	# Start iLO 5 firmware update

	if ($ilo5list.count -eq 0) {
		Write-Host "`nAll iLO 5 devices, if detected, are up-to-date.`n" -ForegroundColor Green
	} else {
		Write-Host "`nUpgrading $ilo5count out-of-date iLO 5 firmware devices... (this may take up to 15 minutes)" -ForegroundColor Cyan
		Set-WindowTitle -Title "Upgrading ilO 5 firmware"
		UpgradeiLOFirmware $ilo5list $ilo5FileLocation
    }
    
    # Wait for iLO devices to reset following the upgrade
    if ($global:badlogin -eq $false) {
        Write-Host "Waiting for two minutes while iLO devices reset." -ForegroundColor Cyan
        Start-Sleep -Seconds 120
    }

    # Verify that the firmware upgrade was successful
    VerifyiLOFirmware $iloIPlist

    # Display iLO's that experienced errors during information gathering
    if ($errorlist.count -gt 0) {
        Write-Host "`nERRORS DURING DATA GATHERING" -ForegroundColor Red
        Write-Host "----------------------------" -ForegroundColor DarkGray
        for ($i = 0; $i -lt $errorlist.count; $i++) {
            Write-Host $errorlist[$i] -ForegroundColor Red
        }
    }

} else {
	Write-Host "Module HPEiLOCmdlets is not loaded or does not meet the minimum version requirement (2.0.0.1)" -ForegroundColor Red
	Write-Host "Exiting script..."
}

Set-WindowTitle -Title "Administrator: Windows PowerShell"
Set-TaskbarNotification -Message "iLOFWupgrade Completed"