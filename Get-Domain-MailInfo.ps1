﻿<#
 .SYNOPSIS
  Get MailInfo for domain(s).

  Default is to retrieve MX, SPF and DMARC records. 
  * Will recognize Null MX - RFC7505
  
  Optionally add -CheckDKIM 1 to retrieve DKIM record.
  * Note requirement to provide DKIMSelector
    Will fall back to using -DKIMSelector Selector1 (Microsoft Exchange Online)
    
  - Outputs to DomainResults.csv and console.
  - Uses System Default List Separator Character and Quotes to simplify CSV processing.
 .LINK
  https://github.com/dotBATmanNO/PSGet-Domain-MailInfo/
 .EXAMPLE
  .\Get-Domain-MailInfo
  "Domain";"HasMX";"HasSPF";"HasDKIM";"HasDMARC";"MXRecord";"SPFRecord";"DKIMSelector";"DKIMRecord";"DMARCRecord"
  "example.com";"True";"True";"#N/A";"False";".";"v=spf1 -all";"#N/A";"#N/A";"False"
 .EXAMPLE
  .\Get-Domain-MailInfo.ps1 -CheckDKIM 1
  "Domain";"HasMX";"HasSPF";"HasDKIM";"HasDMARC";"MXRecord";"SPFRecord";"DKIMSelector";"DKIMRecord";"DMARCRecord"
  "example.com";"True";"True";"False";"False";".";"v=spf1 -all";"Selector1";"False";"False"
 .EXAMPLE
  .\Get-Domain-MailInfo.ps1 -Name "-invalid.name" -verbose
  VERBOSE:  Script Get-Domain-MailInfo.ps1
  VERBOSE:  Last Updated 2019-10-01
  VERBOSE: 
  VERBOSE:  Checking 00001 domain(s)
  VERBOSE: 
  VERBOSE: 
  "Domain";"HasMX";"HasSPF";"HasDKIM";"HasDMARC";"MXRecord";"SPFRecord";"DKIMSelector";"DKIMRecord";"DMARCRecord"
  VERBOSE: Fail: Domain lookup failed - probable invalid domain name (-invalid.name)
  "-invalid.name";"#N/A";"#N/A";"#N/A";"#N/A";"#N/A";"#N/A";"#N/A";"#N/A";"#N/A"
#>
[CmdletBinding(
  DefaultParameterSetName="Name")]
  param (
    # Script execution option 1 is to check ONE domain
    [Parameter(ParameterSetName="Name")]
    [string]$Name = "example.com",
    # Script execution option 2 is to check a list of domains from a file, one domain per line
    [Parameter(ParameterSetName="Path")]
    [string]$Path,
    # Default is to check SPF (RFC7208)
    [bool]$CheckSPF=$true,
    # Default is to check DMARC (RFC7489)
    [bool]$CheckDMARC=$true,
    # Default is NOT to check DKIM (RFC6376)
    # If you add -CheckDKIM 1 you should also specify -DKIMSelector <selector>
    [bool]$CheckDKIM=$false,
    # Specify the DKIMSelector to check, tip is to check received e-mail.
    # Note: The script defaults to Selector1, used for Microsoft Exchange online.
    #       You could try -DKIMSelector google for G-Suite
    [string]$DKIMSelector="Selector1",
    # Default is to overwrite the .CSV file.
    # Note: The script will check for file lock and softfail.
    #       Remember to close the CSV file before running the script again.
    [bool]$Overwrite=$true,
    # The UseHeader line preference follows Overwrite unless specified
    [bool]$UseHeader=$Overwrite)

Function fnIsDomain {

  param ([string]$domname)
   
   Try
   {
    $DNSRecord = Resolve-DnsName -Name $domname 2> $null
   }
   Catch
   {
    $DNSRecord = $False
   }
   If ($DNSRecord)
   {
    Return $true
   }
   else
   {
    # DNS lookup failed - Match $domainname to RegEx - note not supporting punycode
    # Source https://stackoverflow.com/questions/11809631/ 
    If ($domname -notmatch "(?=^.{4,253}$)(^((?!-)[a-zA-Z0-9-]{1,63}(?<!-)\.)+[a-zA-Z]{2,63}$)")
    {
     Write-Verbose "Fail: Domain lookup failed - probable invalid domain name ($domname)"
    }
    Return $False
   }
} # End Function fnMXRecord

Function fnMXRecord {

  param ([string]$domname)
   
   Try
   {
    $MXRecord = Resolve-DnsName -Name $domname -Type MX 2> $null
   }
   Catch
   {
    Return $False
   }
   

   If ( $MXRecord.NameExchange )
   {
    $MXRec = $MXRecord.NameExchange
    
    # Return multiple MX records as comma separated list.
    If ( $MXRec -is [Array]) { $MXRec = $MXRec -join "," }
    If ( $MXRec -eq "." )    { $MXRec = "Null MX (RFC7505)"}
    Return $MXRec
   }
   Else
   {
    Return $False
   }
} # End Function fnMXRecord

Function fnSPFRecord {

  param ([string]$DomName)
   Try
   {
    $SPFRecord = Resolve-DnsName -Name $domname -Type TXT | Where strings -LIKE "v=spf1*" 
   }
   Catch
   {
    Return $False
   }
   If ($SPFRecord.Strings)
   { 
    $SPFRec = $SPFRecord | Select-Object -ExpandProperty Strings
    Return $SPFRec
   }
    Else
   {
     Return $False
   }
} # End Function fnSPFRecord

Function fnDKIMRecord {

  param ([string]$domname, [string]$selector)
   
   If ($selector -eq "")
   { 
    $selector = Read-Host "Input Selector to use for $domname"
   }
   
   # Build DKIM record selector._domainkey.domainname
   $strDKIMrec = "$($selector)._domainkey.$($domname)"

   Try 
   {
    $strDKIMRecord = Resolve-DnsName -Name $strDKIMrec -Type TXT 2> $null
   }
   Catch
   {
    Return $False
   }
   If ($strDKIMRecord.Strings)
   {
    $strDKIMRecord = $strDKIMRecord.Strings
    Return "$($Selector)""$($charListSep)""$($strDKIMRecord)"
   }
   Else
   {
    # No DKIM record found for this selector
    Return "$($Selector)""$($charListSep)""False"
   }
   
} # End Function fnDKIMRecord

Function fnDMARCRecord {

  param ([string]$domname)

   Try
   {
     $DMARCRecord = Resolve-DnsName -Name _dmarc.$domname -Type TXT 2> $null
   }
   Catch
   {
    Return $False
   }
   
   If ($DMARCRecord.Strings)
   {
    $DMARCRec = $DMARCRecord | Select-Object -ExpandProperty Strings
    Return $DMARCRec
   }
   Else
   {
    # _dmarc DNS entry exists but is not a TXT record - invalid?
    Return $False
   }
} # End Function fnDMARCrecord

Function fnCheckCSVFileLock {
  param ([string]$CSVFileName, [bool]$CreateFile)
  
  # Check if file exists
  If (Test-Path -Path $CSVFileName -PathType Leaf)
  {
   # File Exists, can we write to it?
   Try
   {
    $FileStream = [System.IO.File]::Open($CSVFileName,'Open','Write')
   }
   Catch
   {
    # File Write failed - must be locked
    Write-Verbose ".. the script will not be able to output results to .CSV file"
    Write-Verbose "   (Is the file still open in Excel or other program?)"
    Return $true
   }
   
   # File is not locked - Let's close it to leave it available
   $FileStream.Close()
   $FileStream.Dispose()
   
   # If we are not asked to create a blank file we are ready to return
   If (-Not $CreateFile) { Return $false }
  }
   
  New-Item -Path $CSVFileName -ItemType File -Force -InformationAction Ignore | Out-Null  
  Return $false 

}

# Initialize Script
# First step is to define script settings
$ScriptPath = Split-Path -parent $PSCommandPath     # Use the folder the script was started from
$charListSep = (Get-Culture).TextInfo.ListSeparator # Get the local system list separator
$csvFile = "$ScriptPath\DomainResults.csv"          # Place the DomainResults.csv in script folder
$bolCSV = $true                                     # Bolean value used to detect If CSV file is locked
If ($CheckDKIM -eq $False) { $DKIMSelector = ""}    # If DKIM is not checked we do not need a selector

# Header line using quotes and system default list separator character
$arrheader = """Domain", "HasMX", "HasSPF", "HasDKIM", "HasDMARC", 
             "MXRecord", "SPFRecord", "DKIMSelector", "DKIMRecord", "DMARCRecord"""
$headerline = $arrheader -join """$($charlistsep)"""

# Use array, even If only one domain has been provided
If ($Path)
{ $arrDomains = Get-Content $Path 2> $null }
else
{ $arrDomains = $Name }

If ($arrDomains.Count -eq 0) 
{
 # No Domains to check - must be a fileread issue.
 Write-Host "Unable to read domains from file $Path." 
 Break 
} 

# Verbose Script information on Script version and parameters
$strDomainsToCheck = $arrDomains.Count.ToString().PadLeft(5, "0")
Write-Verbose " Script Get-Domain-MailInfo.ps1"
Write-Verbose " Last Updated 2019-10-01"
Write-Verbose ""
Write-Verbose " Checking $($strDomainsToCheck) domain(s)"
If ($CheckDKIM) { Write-Verbose " .. checking DKIM using selector $($DKIMSelector)" }
# End Script information Verbose block

# Check If CSVFile Exists and if it is locked
# If available - create new file if requested
If (fnCheckCSVFileLock -CSVFileName $csvFile -CreateFile $Overwrite)
{
 # File exists and is locked.
 # Softfail to run script with no output to CSV.
 $bolCSV = $false
}
else
{
 If ($UseHeader) { Add-Content -Path $CSVFile -Value $headerline }
} 

If ($UseHeader) { Write-Host $headerline } 

# Start enumerating the domain(s) that have been nominated
ForEach ( $domainname in $arrDomains )
{
 # First check is to see if this domain can be resolved
 If (fnIsDomain($domainname))
 {
  # Next we try to resolve the MX and SPF records
  $dominfoMX = fnMXRecord -domname $domainName

  # We check SPF even if there is no MX record.
  If ($CheckSPF) 
  { 
   $dominfoSPFDet = fnSPFRecord -DomName $domainName 
   If ($dominfoSPFDet) { $dominfoSPF = "True" } else { $dominfoSPF = $dominfoSPFDet = "False" }
  }
  else
  {
   $dominfoSPF = $dominfoSPFDet = "#N/A"
  }

  If ($dominfoMX)
  {
   # Got MX - let's check DKIM
   If ($CheckDKIM)
   {
    $dominfoDKIMDet = fnDKIMRecord -Domname $domainName -Selector $DKIMSelector
    If ($dominfoDKIMDet -match "DKIM1")
    {
     $dominfoDKIM = "True"
    }
    Else
    {
     $dominfoDKIM = "False"
    }
   }
   else
   {
    # Not checking DKIM, let's return #N/A
    $dominfoDKIM = "#N/A"
    $dominfoDKIMDet = "#N/A""$($charlistSep)""#N/A"
   } # End DKIM Check

   # Done with DKIM - Let's check DMARC
   If ($CheckDMARC)
   {
    $dominfoDMARCDet = fnDMARCRecord($domainName)
    If ($dominfoDMARCDet) { $dominfoDMARC = "True" } else { $dominfoDMARC = $dominfoDMARCDet = "False" }
   }
   else
   {
    $dominfoDMARC = "False"
    $dominfoDMARCDet = "#N/A" 
   }
   # Build result line using quotes and system default list separator character
   $arrLine = """$DomainName", "True", $dominfoSPF, $dominfoDKIM, $dominfoDMARC,
                     $dominfoMX, "$($dominfoSPFDet)", $dominfoDKIMDet, "$dominfoDMARCDet"""
   $ContentLine =  $arrLine -join """$($charlistsep)"""
  }
  else 
  {
   # No MX Record Found, return SPF if found - other checks were skipped
   $arrLine = """$DomainName", "False", $dominfoSPF, "#N/A", "#N/A",
                     "#N/A", "$($dominfoSPFDet)", "#N/A", "#N/A", "#N/A"""
   $ContentLine = $arrLine -join """$($charlistsep)"""
   $ContentLine =  $arrLine -join """$($charlistsep)"""

  }
  
 }
 else
 {
  # Domain lookup failed - set all columns but domainname to #N/A
  # Using Fill Array tip from https://stackoverflow.com/questions/17875852/
  $arrline = ,"#N/A" * 9
  $ContentLine = $arrLine -join """$($charlistsep)"""
  $ContentLine = """$($domainname)""$($charlistsep)""$($ContentLine)"""
 }
 # Return output to CSV (if not disabled) and screen.
 If ($bolCSV) { Add-Content -Path $csvFile -Value $ContentLine }
 Write-Host $ContentLine
 Clear-Variable dominfo*
}