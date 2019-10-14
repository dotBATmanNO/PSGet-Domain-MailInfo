# PSGet-Domain-MailInfo
PowerShell script to get domain mail info such as MX, SPF, DKIM and DMARC.

Outputs to CSV file and to PowerShell Pipeline.

Example use:
```
$mydomains = .\Get-Domain-MailInfo -Path .\MyDomains.txt -CheckDKIM 1
```
(progress bar will be shown - enumerating each domain as it is checked)
The array $mydomains now holds the result for all requested domain names.

List the domainnames that have SPF:
```
$domains | Where-Object -FilterScript { $_.HasSPF -eq $true } | Select-Object $_ -ExpandProperty Domain
```

Print information for one domain:
```
$domains[nn]
```
or named 
```
$domains.where{ $_.Domain -eq "example.com" }

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
```

More information and examples can be found using Get-Help, see output below:

```
PS C:\> Get-Help .\Get-Domain-MailInfo.ps1 -Full

NAME
    C:\Get-Domain-MailInfo.ps1

SYNOPSIS
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

SYNTAX
    C:\Get-Domain-MailInfo.ps1 [-Name <String>] [-CheckSPF <Boolean>] [-CheckDMARC <Boolean>] [-CheckDKIM <Boolean>] [-DKIMSelector <String[]>] [-Overwrite <Boolean> [-UseHeader <Boolean>] [<CommonParameters>]

    C:\Get-Domain-MailInfo.ps1 [[-Name] <String>] [-Path <String>] [-CheckSPF <Boolean>] [-CheckDMARC <Boolean>] [-CheckDKIM <Boolean>] [-DKIMSelector <String[]>] [-Overwrite <Boolean>] [-UseHeader <Boolean>] [<CommonParameters>]

PARAMETERS
    -Name <String>
        Script execution option 1 is to check ONE domain

        Required?                    false
        Position?                    1
        Default value                example.com
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -Path <String>
        Script execution option 2 is to check a list of domains from a file, one domain per line

        Required?                    false
        Position?                    named
        Default value
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -CheckSPF <Boolean>
        Default is to check SPF (RFC7208)

        Required?                    false
        Position?                    named
        Default value                True
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -CheckDMARC <Boolean>
        Default is to check DMARC (RFC7489)

        Required?                    false
        Position?                    named
        Default value                True
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -CheckDKIM <Boolean>
        Default is NOT to check DKIM (RFC6376)
        If you add -CheckDKIM 1 you should also specify -DKIMSelector <selector>

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -DKIMSelector <String[]>
        Specify the DKIMSelector(s) to check separated by comma.
        Tip: Send an e-mail to external mailbox for each system to check Selector for.
        Note: The script defaults to -DKIMSelector Selector1, Selector2
              This is the default used by Microsoft Exchange online.
              You could try -DKIMSelector google for G-Suite

        Required?                    false
        Position?                    named
        Default value                @("Selector1", "Selector2")
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -Overwrite <Boolean>
        Default is to overwrite the .CSV file.
        Note: The script will check for file lock and softfail.
              Remember to close the CSV file before running the script again.

        Required?                    false
        Position?                    named
        Default value                True
        Accept pipeline input?       false
        Accept wildcard characters?  false

    -UseHeader <Boolean>
        The UseHeader line preference follows Overwrite unless specified

        Required?                    false
        Position?                    named
        Default value                $Overwrite
        Accept pipeline input?       false
        Accept wildcard characters?  false

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https:/go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS C:\>.\Get-Domain-MailInfo

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

    -------------------------- EXAMPLE 2 --------------------------

    PS C:\>.\Get-Domain-MailInfo.ps1 -CheckDKIM 1 | Format-Table -AutoSize

    Domain      HasMX HasSPF HasDKIM HasDMARC MXRecord          SPFRecord   DKIMSelector        DKIMRecord DMARCRecord
    ------      ----- ------ ------- -------- --------          ---------   ------------        ---------- -----------
    example.com  True   True   False    False Null MX (RFC7505) v=spf1 -all Selector1/Selector2      False       False

    -------------------------- EXAMPLE 3 --------------------------

    PS C:\>.\Get-Domain-MailInfo.ps1 github.com -CheckDKIM 1 -DKIMSelector google

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

    -------------------------- EXAMPLE 4 --------------------------

    PS C:\>.\Get-Domain-MailInfo.ps1 -Name "-invalid.name" -verbose | FT

    VERBOSE:  Script Get-Domain-MailInfo.ps1
    VERBOSE:  Last Updated 2019-10-08
    VERBOSE:
    VERBOSE:  Checking 1 domain(s)
    VERBOSE: [INVALID:] Domain lookup failed - probable invalid domain name (-invalid.name)

    Domain        HasMX HasSPF HasDKIM HasDMARC MXRecord SPFRecord DKIMSelector DKIMRecord DMARCRecord
    ------        ----- ------ ------- -------- -------- --------- ------------ ---------- -----------
    -invalid.name #N/A  #N/A   #N/A    #N/A     #N/A     #N/A      #N/A         #N/A       #N/A

    -------------------------- EXAMPLE 5 --------------------------

    PS C:\>.\Get-Domain-MailInfo.ps1 -Path .\DomainList.txt | FT

    Domain       HasMX HasSPF HasDKIM HasDMARC MXRecord          SPFRecord   DKIMSelector DKIMRecord DMARCRecord
    ------       ----- ------ ------- -------- --------          ---------   ------------ ---------- -----------
    example.com   True   True #N/A       False Null MX (RFC7505) v=spf1 -all #N/A         #N/A             False
    -example.com  #N/A   #N/A #N/A        #N/A #N/A              #N/A        #N/A         #N/A              #N/A

RELATED LINKS
    https://github.com/dotBATmanNO/PSGet-Domain-MailInfo/
