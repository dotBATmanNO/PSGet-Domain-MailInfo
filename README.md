# PSGet-Domain-MailInfo
PowerShell script to get domain mail info such as MX, SPF, DKIM, DMARC and StartTLS.

Output is accessible in PowerShell pipeline.
Results are also written to DomainResults.CSV file and optionally to pie-chart PNGs by adding -CreateGraphs 1.

Three example uses for one / a limited number of domain(s):
```
PS C:\>.\Get-Domain-MailInfo example.com
PS C:\>.\Get-Domain-MailInfo example.com, github.com
PS C:\>.\Get-Domain-MailInfo example.com, github.com -CreateGraphs 1 -CheckDKIM 1 -DKIMSelector google
```
Example where a variable is assigned the data that is returned when checking domains listed in a txt file:
```
$mydomains = .\Get-Domain-MailInfo -Path .\MyDomains.txt -CheckDKIM 1 -DKIMSelector google -PolicyChecks Microsoft,Google
```
(progress bar will be shown - enumerating each domain as it is checked)
The array $mydomains now holds the result for all requested domain names.

List the domainnames that have SPF:
```
$mydomains | Where-Object -FilterScript { $_.HasSPF -eq $true } | Select-Object $_ -ExpandProperty Domain
```

Print information for one domain:
```
$mydomains[nn] | Format-Table
```
or named 
```
$mydomains.where{ $_.Domain -eq "example.com" }

Domain       : example.com
HasMX        : True
HasSPF       : True
HasDKIM      : True
HasDMARC     : True
HasStartTLS  : #N/A
MXRecord     : Null MX (RFC7505)
SPFRecord    : v=spf1 -all
DKIMSelector : google
DKIMRecord   : [google]v=DKIM1; p=
DMARCRecord  : v=DMARC1;p=reject;sp=reject;adkim=s;aspf=s
DMARCPolicy  : p=reject
PolicyChecks : [Microsoft]Qualified(SPFTrue;DKIMTrue;DMARCTrue;DMARCStrictTrue);[Google]Qualified(SPFTrue;DKIMTrue;DMARCTrue)

```

More information and examples can be found using Get-Help, see output below:

```
PS C:\> Get-Help .\Get-Domain-MailInfo.ps1 -Full
                                                                                                                       
NAME
    C:\Users\torv\OneDrive\Prog2025\PSGet-Domain-MailInfo\Get-Domain-MailInfo.ps1

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
    .\Get-Domain-MailInfo.ps1 [-Name <String[]>] [-CheckSPF <Boolean>] [-CheckDMARC <Boolean>] [-CheckDKIM <Boolean>]
    [-DKIMSelector <String[]>] [-DNSServer <String>] [-ForceDNSServer <Boolean>] [-CheckStartTLS <Boolean>]
    [-Overwrite <Boolean>] [-UseHeader <Boolean>] [-CreateGraphs <Boolean>] [-PolicyChecks <String[]>] [<CommonParameters>]

    .\Get-Domain-MailInfo.ps1 [[-Name] <String[]>] [-Path <String>] [-CheckSPF <Boolean>] [-CheckDMARC <Boolean>]
    [-CheckDKIM <Boolean>] [-DKIMSelector <String[]>] [-DNSServer <String>] [-ForceDNSServer <Boolean>]
    [-CheckStartTLS <Boolean>] [-Overwrite <Boolean>] [-UseHeader <Boolean>] [-CreateGraphs <Boolean>]
    [-PolicyChecks <String[]>] [<CommonParameters>]


DESCRIPTION


PARAMETERS
    -Name <String[]>
        Script execution option 1 is to check ONE domain

        Required?                    false
        Position?                    1
        Default value                example.com
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Path <String>
        Script execution option 2 is to check a list of domains from a file, one domain per line

        Required?                    false
        Position?                    named
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -CheckSPF <Boolean>
        Default is to check SPF (RFC7208)

        Required?                    false
        Position?                    named
        Default value                True
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -CheckDMARC <Boolean>
        Default is to check DMARC (RFC7489)

        Required?                    false
        Position?                    named
        Default value                True
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -CheckDKIM <Boolean>
        Default is NOT to check DKIM (RFC6376)
        If you add -CheckDKIM 1 you should also specify -DKIMSelector <selector>

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Aliases
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
        Aliases
        Accept wildcard characters?  false

    -DNSServer <String>
        Default is to use system default DNS Server

        Required?                    false
        Position?                    named
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -ForceDNSServer <Boolean>
        Default is to check if DNS server is working

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -CheckStartTLS <Boolean>
        Default is to check StartTLS (RFC3207)

        Required?                    false
        Position?                    named
        Default value                True
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Overwrite <Boolean>
        Default is to overwrite the .CSV file.
        Note: The script will check for file lock and softfail.
              Remember to close the CSV file before running the script again.

        Required?                    false
        Position?                    named
        Default value                True
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -UseHeader <Boolean>
        The UseHeader line preference follows Overwrite unless specified

        Required?                    false
        Position?                    named
        Default value                $Overwrite
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -CreateGraphs <Boolean>
        The CreateGraph option is set to False by default as it is just a nice-to-have.
        Will create one .PNG pie-chart per protection type; HasSPF/HasDKIM/HasDMARC.

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -PolicyChecks <String[]>
        Policy Check tool was created to help validate if the email polices for
        a domain pass the requirements of named service providers. E.g. Microsoft.
        Specify the Policy Checks to perform separated by comma.

        Required?                    false
        Position?                    named
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

INPUTS

OUTPUTS

    -------------------------- EXAMPLE 1 --------------------------

    PS > .\Get-Domain-MailInfo
    Domain       : example.com
    HasMX        : True
    HasSPF       : True
    HasDKIM      : #N/A
    HasDMARC     : False
    HasStartTLS  : #N/A
    MXRecord     : Null MX (RFC7505)
    SPFRecord    : v=spf1 -all
    DKIMSelector : #N/A
    DKIMRecord   : #N/A
    DMARCRecord  : False
    DMARCPolicy  : none
    PolicyChecks : #N/A

    -------------------------- EXAMPLE 2 --------------------------

    PS > .\Get-Domain-MailInfo.ps1 -CheckDKIM 1 | Format-Table -AutoSize
    Domain      HasMX HasSPF HasDKIM HasDMARC HasStartTLS MXRecord          SPFRecord   DKIMSelector        DKIMRecord DMARCPolicy PolicyChecks  
    ------      ----- ------ ------- -------- ----------- --------          ---------   ------------        ---------- ----------- ------------  
    example.com  True   True   False    False #N/A        Null MX (RFC7505) v=spf1 -all Selector1/Selector2      False #N/A        #N/A

    -------------------------- EXAMPLE 3 --------------------------

    PS > .\Get-Domain-MailInfo.ps1 github.com -CheckDKIM 1 -DKIMSelector google -PolicyChecks Microsoft
    [Notice: ] Could not connect to the SMTP Server alt1.aspmx.l.google.com

    Domain       : github.com
    HasMX        : True
    HasSPF       : True
    HasDKIM      : True
    HasDMARC     : True
    HasStartTLS  : False
    MXRecord     : aspmx.l.google.com,alt4.aspmx.l.google.com,alt3.aspmx.l.google.com,alt2.aspmx.l.google.com,alt1.aspmx.l.
                   google.com
    SPFRecord    : v=spf1 ip4:192.30.252.0/22 include:_netblocks.google.com include:_netblocks2.google.com include:_netbloc
                   ks3.google.com include:spf.protection.outlook.com include:mail.zendesk.com include:_spf.salesforce.com i
                   nclude:servers.mcsv.net include:mktomail.com ip4:166.78.69.169 ip4:166.78.69.170 ip4:166.78.71.131 ip4:1
                   67.89.101.2 ip4:167.89.101.192/28 ip4:192.254.112.60 ip4:192.254.112.98/31 ip4:192.254.113.10 ip4:192.25
                   4.113.101 ip4:192.254.114.176 ip4:62.253.227.114 ~all
    DKIMSelector : google
    DKIMRecord   : [google]v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAj6T5sl/RwdSqGoYWaWaFbS2UAeyPrEmd0g
                   ogocmRfS441qwR8/0KB81Hw89P0l4YiFRrXYk7NVIGfyCRHAYYZUzCkGeOysI2EjgzLFhd/NEsbRzOEc/kWkK/RO6JFq/5lOn6M9AZw/
                   ap9tds4JG9ApgNNdSpPxp9DmvpsOSgNMVflRxQFrk3kdS4RNAPKu/OP
    DMARCRecord  : v=DMARC1; p=reject; pct=100; rua=mailto:dmarc@github.com
    DMARCPolicy  : p=reject
    PolicyChecks : [Microsoft]Unqualified(SPFTrue;DKIMTrue;DMARCTrue;DMARCStrictFalse);[Google]Qualified(SPFTrue;DKIMTrue;DMARCTrue)

    -------------------------- EXAMPLE 4 --------------------------

    PS > .\Get-Domain-MailInfo.ps1 -Name "-invalid.name" -verbose | FT
    VERBOSE:  Script Get-Domain-MailInfo.ps1
    VERBOSE:  Last Updated 2025-05-09
    VERBOSE:
    VERBOSE:  Checking 1 domain(s)
    VERBOSE: [INVALID:] Domain lookup failed - probable invalid domain name (-invalid.name)

    Domain        HasMX HasSPF HasDKIM HasDMARC HasStartTLS MXRecord SPFRecord DKIMSelector DKIMRecord DMARCPolicy PolicyChecks
    ------        ----- ------ ------- -------- ----------- -------- --------- ------------ ---------- ----------- ------------
    -invalid.name #N/A  #N/A   #N/A    #N/A     #N/A        #N/A     #N/A      #N/A         #N/A       none        #N/A

    -------------------------- EXAMPLE 5 --------------------------

    PS > .\Get-Domain-MailInfo.ps1 -Path .\DomainList.txt | FT
    Domain       HasMX HasSPF HasDKIM HasDMARC HasStartTLS MXRecord          SPFRecord   DKIMSelector DKIMRecord DMARCPolicy PolicyChecks        
    ------       ----- ------ ------- -------- ----------- --------          ---------   ------------ ---------- ----------- ------------        
    example.com   True   True #N/A       False #N/A        Null MX (RFC7505) v=spf1 -all #N/A         #N/A       p=reject    #N/A
    -example.com  #N/A   #N/A #N/A        #N/A #N/A        #N/A              #N/A        #N/A         #N/A       #N/A        #N/A

RELATED LINKS
    https://github.com/dotBATmanNO/PSGet-Domain-MailInfo/
