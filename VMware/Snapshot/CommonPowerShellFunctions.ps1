# Script:
# CommonPowerShellFunctions
# 
# Purpose:
# Functions needed by other scripts
# 
#


#  ----------------
#  Local log format
#   
#  Mon Feb 2 22:07:20 2015 errorlevel=INFO message=Example message
#  ----------------


$CurDate           = (Get-Date -format "yyyy-MM-dd HH:mm")
$CurDateFriendly   = (Get-Date -format "dddd MMMM d yyyy - HH:mm")




# -------------------------------------------------------------------------------------------------------------------
# 
# Typical Script Actions - Logging
# 
# -------------------------------------------------------------------------------------------------------------------



# Logging parameters for typical scripts

$timestamp                      = Get-Date -format "ddd MMM d HH:mm:ss yyyy" # in function LogData
$scriptlogfile                  = (Get-Date -format "yyyyMMdd") + ".log"



# Begin Log Directory actions

    # Ensure log directory exists
    If (!(Test-Path $scriptlogdir))
        {New-Item -ItemType directory -Path $scriptlogdir}
        
    # Clean log files
    Get-ChildItem $scriptlogdir -recurse -include *.log*,*.html* | where {$_.lastwritetime -lt (get-date).adddays(-$scriptlogdirretention) -and -not $_.psiscontainer} |% {remove-item $_.fullname -force}

# End Log Directory actions





# -------------------------------------------------------------------------------------------------------------------
# 
# Utility Functions
# 
# -------------------------------------------------------------------------------------------------------------------


Function LogData
{
    param ([string]$lvl, [string]$msg) 
    
    $timestamp = Get-Date -format "ddd MMM d HH:mm:ss yyyy"
    Add-Content $scriptlogdir\$scriptlogfile "$timestamp errorlevel=$lvl message=$msg"

} # End of LogData


Function EmailNotify
{
    Param
    (
        [Parameter(Mandatory=$true)]
        [String]$subject,

        [Parameter(Mandatory=$true)]
        [String]$body,

        [Parameter(Mandatory=$false)]
        [String]$html,

        [Parameter(Mandatory=$false)]
        [String]$priority

    )

    If (!($priority))
    {$priority = "Normal"}


    If ($html -eq "True")
        {Send-MailMessage -to $EmlRecip -from $EmlSender -smtpserver $SmtpServer -subject $subject -body ($body | Out-String) -BodyAsHtml -Priority $priority
        }
    Else
        {Send-MailMessage -to $EmlRecip -from $EmlSender -smtpserver $SmtpServer -subject $subject -body $body -Priority $priority
        }
        


      
} # End of EmailNotify


Function PageNotify
{
    param ([string]$subject, [string]$body) 
      
      Send-MailMessage -to $EmlPageRecip -from $EmlSender -smtpserver $SmtpServer -subject $subject -body $body
      
} # End of EmailNotify



# -------------------------------------------------------------------------------------------------------------------
# 
# Formatting Functions
# 
# -------------------------------------------------------------------------------------------------------------------

<#
$a = @{Expression={$objSnapTemp.VirtualMachine};Label="Virtual Machine";width=25}, `
@{Expression={$objSnapTemp.Snapshot};Label="Snapshot";width=20}, `
@{Expression={$objSnapTemp.SizeGB};Label="Size";width=15}, `
@{Expression={$objSnapTemp.Created};Label="Creation Date";width=20}
#>


# $hf is called inside other scripts and/or added to - stands for "html output"
$hf = @"
<style>
title{font-size:18px; display:inline}
BODY{background-color:white; font-family:Calibri}
TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse}
TH{border-width: 1px;padding: 6px;border-style: solid;border-color: black;background-color:#00b5d8}
TD{border-width: 1px;padding: 6px;border-style: solid;border-color: black}
TR:Hover TD {Background-Color: #C1D5F8;}
.odd  { background-color:#ffffff; }
.even { background-color:#dddddd; }
</style>
"@



Function Set-AlternatingRows {
	<#
	.SYNOPSIS
		Simple function to alternate the row colors in an HTML table
	.DESCRIPTION
		This function accepts pipeline input from ConvertTo-HTML or any
		string with HTML in it.  It will then search for <tr> and replace 
		it with <tr class=(something)>.  With the combination of CSS it
		can set alternating colors on table rows.
		
		CSS requirements:
		.odd  { background-color:#ffffff; }
		.even { background-color:#dddddd; }
		
		Classnames can be anything and are configurable when executing the
		function.  Colors can, of course, be set to your preference.
		
		This function does not add CSS to your report, so you must provide
		the style sheet, typically part of the ConvertTo-HTML cmdlet using
		the -Head parameter.
	.PARAMETER Line
		String containing the HTML line, typically piped in through the
		pipeline.
	.PARAMETER CSSEvenClass
		Define which CSS class is your "even" row and color.
	.PARAMETER CSSOddClass
		Define which CSS class is your "odd" row and color.
	.EXAMPLE $Report | ConvertTo-HTML -Head $Header | Set-AlternateRows -CSSEvenClass even -CSSOddClass odd | Out-File HTMLReport.html
	
		$Header can be defined with a here-string as:
		$Header = @"
		<style>
		TABLE {border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
		TH {border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color: #6495ED;}
		TD {border-width: 1px;padding: 3px;border-style: solid;border-color: black;}
		.odd  { background-color:#ffffff; }
		.even { background-color:#dddddd; }
		</style>
		"@
		
		This will produce a table with alternating white and grey rows.  Custom CSS
		is defined in the $Header string and included with the table thanks to the -Head
		parameter in ConvertTo-HTML.
	.NOTES
		Author:         Martin Pugh
		Twitter:        @thesurlyadm1n
		Spiceworks:     Martin9700
		Blog:           www.thesurlyadmin.com
		
		Changelog:
			1.1         Modified replace to include the <td> tag, as it was changing the class
                        for the TH row as well.
            1.0         Initial function release
	.LINK
		http://community.spiceworks.com/scripts/show/1745-set-alternatingrows-function-modify-your-html-table-to-have-alternating-row-colors
    .LINK
        http://thesurlyadmin.com/2013/01/21/how-to-create-html-reports/
	#>
    [CmdletBinding()]
   	Param(
       	[Parameter(Mandatory,ValueFromPipeline)]
        [string]$Line,
       
   	    [Parameter(Mandatory)]
       	[string]$CSSEvenClass,
       
        [Parameter(Mandatory)]
   	    [string]$CSSOddClass
   	)
	Begin {
		$ClassName = $CSSEvenClass
	}
	Process {
		If ($Line.Contains("<tr><td>"))
		{	$Line = $Line.Replace("<tr>","<tr class=""$ClassName"">")
			If ($ClassName -eq $CSSEvenClass)
			{	$ClassName = $CSSOddClass
			}
			Else
			{	$ClassName = $CSSEvenClass
			}
		}
		Return $Line
	}
}