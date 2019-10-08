<#
 .SYNOPSIS
  Get MailInfo for domain(s).

  Default is to retrieve MX, SPF and DMARC records. 
  * Will recognize Null MX - RFC7505
  
  Optionally add -CheckDKIM 1 to retrieve DKIM record(s).
  * Note requirement to provide DKIMSelector parameter.
    This parameter is a text array - provide selectors separated by comma

    Will fall back to using -DKIMSelector Selector1, Selector2 (Microsoft Exchange Online)
    
    Returns two columns
    - DKIMSelector holding all Selectors tested, separated by /
    - DKIMRecord holding [Selector1]DKIMRecord1/[Selector2]DKIMRecord2
    
    Example below is typically seen when DNS has wildcard TXT/SOA record:
    "Selector1/Selector2";"[Selector1]NoDKIMRecord/[Selector2]NoDKIMRecord"
    
  - Outputs to DomainResults.csv and console.
  - Uses System Default List Separator Character and Quotes to simplify CSV processing.
 .LINK
  https://github.com/dotBATmanNO/PSGet-Domain-MailInfo/
 .EXAMPLE
  .\Get-Domain-MailInfo
  Domain       : example.com
  HasMX        : True
  HasSPF       : True
  HasDKIM      : #N/A
  HasDMARC     : False
  MXRecord     : Null MX (RFC7505)
  SPFRecord    : v=spf1 -all
  DKIMSelector : #N/A
  DKIMRecord   : #N/A
  DMARCRecord  : False
 .EXAMPLE
  .\Get-Domain-MailInfo.ps1 -CheckDKIM 1 | Format-Table -AutoSize
  Domain      HasMX HasSPF HasDKIM HasDMARC MXRecord          SPFRecord   DKIMSelector        DKIMRecord DMARCRecord
  ------      ----- ------ ------- -------- --------          ---------   ------------        ---------- -----------
  example.com  True   True   False    False Null MX (RFC7505) v=spf1 -all Selector1/Selector2      False       False
 .EXAMPLE
  .\Get-Domain-MailInfo.ps1 github.com -CheckDKIM 1 -DKIMSelector google
  Domain       : github.com
  HasMX        : True
  HasSPF       : True
  HasDKIM      : True
  HasDMARC     : True
  MXRecord     : aspmx.l.google.com,alt3.aspmx.l.google.com,alt2.aspmx.l.google.com,alt1.aspmx.l.google.com,alt4.aspmx.l.google.com
  SPFRecord    : v=spf1 ip4:192.30.252.0/22 ip4:208.74.204.0/22 ip4:46.19.168.0/23 include:_spf.google.com include:esp.github.com include:_spf.createsend.com include:servers.mcsv.net ~all
  DKIMSelector : google
  DKIMRecord   : [google]v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCNcsfnwX5c/B/MF/7J6/kDTO7rl08yEcrDLMDPp2YONNwqqpZxRSNt+cI8am8ixoPQ0V0bMVu1mYwZEV59u96vZFjVQIkfh08Y7q1jSjjd35FoaQl4YS5H4q6C4ARaC70jf2/NEDUUJFImkPKUZ42SV7MWQs2NnAEOXNQwvWmbCwIDAQAB
  DMARCRecord  : v=DMARC1; p=none; rua=mailto:dmarc@github.com
.EXAMPLE
  .\Get-Domain-MailInfo.ps1 -Name "-invalid.name" -verbose | FT
  VERBOSE:  Script Get-Domain-MailInfo.ps1
  VERBOSE:  Last Updated 2019-10-07
  VERBOSE:
  VERBOSE:  Checking 1 domain(s)
  VERBOSE: [INVALID:] Domain lookup failed - probable invalid domain name (-invalid.name)

  Domain        HasMX HasSPF HasDKIM HasDMARC MXRecord SPFRecord DKIMSelector DKIMRecord DMARCRecord
  ------        ----- ------ ------- -------- -------- --------- ------------ ---------- -----------
  -invalid.name #N/A  #N/A   #N/A    #N/A     #N/A     #N/A      #N/A         #N/A       #N/A
.EXAMPLE
  .\Get-Domain-MailInfo.ps1 -Path .\DomainList.txt | FT
  Domain       HasMX HasSPF HasDKIM HasDMARC MXRecord          SPFRecord   DKIMSelector DKIMRecord DMARCRecord
  ------       ----- ------ ------- -------- --------          ---------   ------------ ---------- -----------
  example.com   True   True #N/A       False Null MX (RFC7505) v=spf1 -all #N/A         #N/A             False
  -example.com  #N/A   #N/A #N/A        #N/A #N/A              #N/A        #N/A         #N/A              #N/A
#>
[CmdletBinding(
  PositionalBinding=$false,DefaultParameterSetName="Name")]
  param (
    # Script execution option 1 is to check ONE domain
    [Parameter(ParameterSetName="Name")]
    [Parameter(Position=0)][string]$Name = "example.com",
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
    # Specify the DKIMSelector(s) to check separated by comma.
    # Tip: Send an e-mail to external mailbox for each system to check Selector for.
    # Note: The script defaults to -DKIMSelector Selector1, Selector2
    #       This is the default used by Microsoft Exchange online.
    #       You could try -DKIMSelector google for G-Suite
    [string[]]$DKIMSelector=@("Selector1", "Selector2"),
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
    $DNSRecord = Resolve-DnsName -Name $domname -DnsOnly -ErrorAction Stop 2> $null
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
     Write-Verbose "[INVALID:] Domain lookup failed - probable invalid domain name ($domname)"
    }
    Return $False
   }
} # End Function fnMXRecord

Function fnMXRecord {

  param ([string]$domname)
   
   Try
   {
    $MXRecord = Resolve-DnsName -Name $domname -Type MX -DnsOnly -ErrorAction Stop 2> $null
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
    If ( $MXRec -eq "." )    
    {
      # . (dot) as MX record indicates Null MX
      If ($MXRecord.Preference -eq 0)
     {
      # With a preference of 0 this is a valid NullMX record
      $MXRec = "Null MX (RFC7505)"
     }
     else 
     {
      $MXRec = "[Invalid:] Null MX (RFC7505) should have Preference=0, was $($MXRecord.Preference)."
     }
    }
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
    $SPFRecord = Resolve-DnsName -Name $domname -Type TXT -DnsOnly -ErrorAction Stop 2> $null
   }
   Catch
   {
    Return $False
   }
   If ($SPFRecord.Strings)
   { 
    $SPFRec = $SPFRecord.Strings | Where-Object -FilterScript { $_ -like "v=spf1*" }
    
    If ($SPFRec) { Return $SPFRec }
    
   }

   # No v=SPF1 txt record was found
   Return $False
   
} # End Function fnSPFRecord

Function fnDKIMRecord {

  param ([string]$domname, [string[]]$selector)
   
  # Check for existence of _domainkey
  # This is an easy but not guaranteed way to tell if any Selector(s) exist.
  Try 
  {
   $strDKIMRecord = Resolve-DnsName -Name "_domainkey.$($domname)" -DnsOnly -ErrorAction Stop 2> $null
  }
  Catch
  {
   # Script currently fails the DKIM check if _domainkey does not exist. 
   # Consider if this is always true, e.g. different DNS server implementations.
   Return $False
  }
  
  If ($selector -eq "")
  { 
   $selector = Read-Host "Input Selector to use for $domname"
  }
  
  $strSelectors = $strDKIMRecords = ""
  ForEach ($DKIMSel in $Selector)
  {
   # Build DKIM record selector._domainkey.domainname
   $strDKIMrec = "$($DKIMSel)._domainkey.$($domname)"
   $strDKIMRecord = ""
   
   Try 
   {
    $strDKIMRecord = Resolve-DnsName -Name $strDKIMrec -Type TXT -DnsOnly -ErrorAction Stop 2> $null
   }
   Catch
   {
    $strDKIMRecord = "NoDKIMRecord"
   }
   If ($strDKIMRecord.Strings)
   {
    $strDKIMRecord = $strDKIMRecord.Strings | Where-Object -FilterScript { $_ -like "v=DKIM1*" }
    If ($null -eq $strDKIMRecord)
    {
     Write-Verbose "[INVALID:] TXT record for selector $($DKIMSel) does not start with v=DKIM1"
     $strDKIMRecord = "[INVALID:]$($strDKIMRecord)"
    }
   }
   else
   {
    $strDKIMRecord = "NoDKIMRecord"  
   }
   $strDKIMRecords = "$($strDKIMRecords)/[$($DKIMSel)]$($strDKIMRecord)"
   
  }
  Return $strDKIMRecords.Substring(1)
} # End Function fnDKIMRecord

Function fnDMARCRecord {

  param ([string]$domname)

   Try
   {
    $DMARCRecord = Resolve-DnsName -Name _dmarc.$domname -Type TXT -DnsOnly -ErrorAction Stop 2> $null
   }
   Catch
   {
    Return $False
   }
   
   If ($DMARCRecord.Strings)
   {
    $DMARCRec = $DMARCRecord | Select-Object -ExpandProperty Strings
    
    # Check validity of DMARC record
    If ($DMARCRec -like "v=DMARC1*") 
    {
     Return $DMARCRec
    }
    else
    {
      Write-Verbose "[INVALID:] DMARC record does not start with v=DMARC1"
      Return "[Invalid:]$($DMARCRec)"
    }
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
$ScriptPath = Split-Path -parent $PSCommandPath      # Use the folder the script was started from
$charListSep = (Get-Culture).TextInfo.ListSeparator  # Get the local system list separator
$csvFile = "$ScriptPath\DomainResults.csv"           # Place the DomainResults.csv in script folder
$bolCSV = $true                                      # Bolean value used to detect If CSV file is locked
If ($CheckDKIM -eq $False) { $DKIMSelector = "#N/A"} # If DKIM is not checked we do not need a selector

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
Write-Verbose " Script Get-Domain-MailInfo.ps1"
Write-Verbose " Last Updated 2019-10-07"
Write-Verbose ""
Write-Verbose " Checking $($arrDomains.Count) domain(s)"
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

#If ($UseHeader) { Write-Host $headerline } 
# Initialize an array
$arrOutput = @()

# Create an ordered hashtable and a new PSobject
$rowhash = [ordered]@{
  Domain = "";
  HasMX = "";
  HasSPF = "";
  HasDKIM = "";
  HasDMARC = "";
  MXRecord = "";
  SPFRecord = "";
  DKIMSelector = "";
  DKIMRecord = "";
  DMARCRecord = "";
 }

[int]$iDomain = 0
# Start enumerating the domain(s) that have been nominated
ForEach ( $domainname in $arrDomains )
{
 $iDomain++
 $iDomainPercent = $iDomain/$arrDomains.Count*100
 Write-Progress -Activity "Enumerating $($arrDomains.Count) domain(s)" -Id 1 -PercentComplete $iDomainPercent -CurrentOperation "Checking $($domainname)"

 # Initialize the row PSObject
 $row = New-Object PSObject -Property $rowhash

 # First check is to see if this domain can be resolved
 If (fnIsDomain -domname $domainname)
 {
  # Next we try to resolve the MX and SPF records
  $dominfoMXDet = fnMXRecord -domname $domainName

  # We check SPF even if there is no MX record.
  If ($CheckSPF) 
  { 
   $dominfoSPFDet = fnSPFRecord -DomName $domainName 
   If ($dominfoSPFDet) { $dominfoSPF = $True } else { $dominfoSPF = $dominfoSPFDet = $false }
  }
  else
  {
   $dominfoSPF = $dominfoSPFDet = "#N/A"
  }

  If ($dominfoMXDet)
  {
   # Got MX - let's check DKIM
   $dominfoMX = $true;
   If ($CheckDKIM)
   {
    $dominfoDKIMDet = fnDKIMRecord -Domname $domainName -Selector $DKIMSelector
    If ($dominfoDKIMDet -match "DKIM1")
    {
     $dominfoDKIM = $true
    }
    Else
    {
     $dominfoDKIM = $false
    }
   }
   else
   {
    # Not checking DKIM, let's return #N/A
    $dominfoDKIM = $dominfoDKIMDet = "#N/A"
   } # End DKIM Check

   # Done with DKIM - Let's check DMARC
   If ($CheckDMARC)
   {
    $dominfoDMARCDet = fnDMARCRecord -domname $domainName
    If ($dominfoDMARCDet) { $dominfoDMARC = $true } else { $dominfoDMARC = $dominfoDMARCDet = $false }
   }
   else
   {
    $dominfoDMARC = $false
    $dominfoDMARCDet = "#N/A" 
   }
  }
  else 
  {
    
    # No MX record, set other variables to #N/A
    $dominfoMX = $false
    $dominfoDKIM = "#N/A";
    $dominfoDMARC = "#N/A";
    $dominfoMXDet = "#N/A";
    $dominfoDKIMDet = "#N/A";
    $dominfoDMARCDet = "#N/A";
    
  }
  
 }
 else
 {
  # Domain lookup failed - set all columns but domainname to #N/A
  $dominfoMX = "#N/A"
  $dominfoSPF = "#N/A"
  $dominfoDKIM = "#N/A";
  $dominfoDMARC = "#N/A";
  $dominfoMXDet = "#N/A";
  $dominfoSPFDet = "#N/A";
  $dominfoDKIMDet = "#N/A";
  $dominfoDMARCDet = "#N/A";
    
 }
 $row.Domain = $domainname
 $row.HasMX = $dominfoMX
 $row.HasSPF = $dominfoSPF
 $row.HasDKIM = $dominfoDKIM
 $row.HasDMARC = $dominfoDMARC
 $row.MXRecord = $dominfoMXDet
 $row.SPFRecord = $dominfoSPFDet
 $row.DKIMSelector = $DKIMSelector -Join "/"
 $row.DKIMRecord = $dominfoDKIMDet
 $row.DMARCRecord = $dominfoDMARCDet

 $arroutput += $row
 Clear-Variable row

 Clear-Variable dominfo*
}
# Remove progress bar
Write-Progress -Activity "Enumerating domain(s)" -Id 1 -Completed

# Return output, save to CSV (if not disabled).
If ($bolCSV) { $arrOutput | Export-Csv -Path $csvFile -Append -NoClobber -NoTypeInformation -UseCulture  }
Write-Output $arrOutput