function Get-AllSuccessfulO365LoginEvents {
        
    <#
    .SYNOPSIS
        Gets all successful login events into O365 portal for given time period. Puts them on the desktop in a .csv.
    .EXAMPLE
        Get-AllSuccessfulO365LoginEvents -StartTimeUTC '04/15/18 04:00' -EndTimeUtc '04/20/2018 04:00'
        Search for all users between the specified times.    
    .EXAMPLE
        Get-AllSuccessfulO365LoginEvents -StartTimeUTC '04/15/18 04:00' -EndTimeUtc '04/20/2018 04:00' -User konstantin@ezmsp.com
        Search for a single user with the users UPN.
    #>

    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$false)]
    [string]$ReportPath,
    [Parameter(Mandatory=$false)]
    [string]$User,
    [Parameter(Mandatory=$true)]
    [DateTime]$EndTimeUtc,
    [Parameter(Mandatory=$true)]
    [DateTime]$StartTimeUTC
    )

    #define helper functions
    function Get-IPGeolocation
    {
        #from http://powershell-guru.com/powershell-tip-95-find-the-geolocation-of-an-ip-address/, made to accept pipeline 
        Param
        (
            [parameter(ValueFromPipeline)]
            [string]$IPAddress
        )
    
        $request = Invoke-RestMethod -Method Get -Uri "http://geoip.nekudo.com/api/$IPAddress"
    
        [PSCustomObject]@{
            IP        = $request.IP
            City      = $request.City
            Country   = $request.Country.Name
            Code      = $request.Country.Code
            Location  = $request.Location.Latitude
            Longitude = $request.Location.Longitude
            TimeZone  = $request.Location.Time_zone
        }
    }
    #end helper functions

    if ($ReportPath) {
        #accept the user's input path 
    } else {
        if ($User) {
            $ReportName = ((Get-MsolCompanyInformation).DisplayName) + ' Office 365 All Successful Login Events for ' + "$user" + (Get-Date -Format "yyyy-MM-dd-HH-mm") + '.csv'
        } else {
            $ReportName = ((Get-MsolCompanyInformation).DisplayName) + ' Office 365 All Successful Login Events ' + (Get-Date -Format "yyyy-MM-dd-HH-mm") + '.csv'
        }
        $ReportPath = $env:USERPROFILE + '\Desktop\' + $ReportName
    }

    if ($User) {
        $users = $User
    } else {
        $users = Get-MsolUser -all | Where-Object {$_.isLicensed} | Select-Object -ExpandProperty userprincipalname
    }

    $ipaddresses = @()
    ForEach ($u in $users) {
        $addressestoadd = Search-UnifiedAuditLog -UserIds $u -StartDate $StartTimeUTC -EndDate $EndTimeUtc -resultsize 5000 | 
            Select-Object -ExpandProperty AuditData | Convertfrom-json | Where-object {$_.operation -eq 'UserLoggedIn'} | 
            Select-Object @{Label='Name'; Expression = {$u}}, clientip, CreationTime, `
            @{Label = 'Country'; Expression = {$_.clientip | Get-IPGeolocation | Select-Object -ExpandProperty Country}}, `
            @{Label = 'City'; Expression = {$_.clientip | Get-IPGeolocation | Select-Object -ExpandProperty City}}
        $addressestoadd | Format-Table | Write-Output
        $ipaddresses += $addressestoadd
    }

    $ipaddresses | Export-Csv -NoTypeInformation $ReportPath 


}
