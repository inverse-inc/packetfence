##########################################################################################
#Powershell script to audit and notify a password change on an Active Directory.         #
##########################################################################################
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$base_url = "https://@IP_PACKETFENCE:9999"
$username = "admin" # Username for the webservice
$password = "admin" # Password for the webservice

$credential = @{ "username" = $username; "password" = $password}
$credJson = $credential| ConvertTo-Json

$token_url=$base_url+"/


cls
$eventTypeID = 4724
$events = Get-WinEvent -MaxEvents 10  -FilterHashTable @{ Logname = "Security"; ID = $eventTypeID }

$eventArr = @()

foreach ($event in $events)
{
    $e = @{ }
    $xmlObject = [xml]$event.ToXml()
    $e['recordID'] = $event.RecordId
    $e['eventTime'] = $event.TimeCreated

    if ($xmlObject.Event.EventData.Data.Length -ge 0)
    {
        foreach ($entry in $xmlObject.Event.EventData.Data)
        {
            $e[$entry.Name] = $entry.InnerText
        }
    }
    $eventArr += $e
}

$eventJson = $eventArr | ConvertTo-Json
$url = "http://@PACKETFENCE_IP:@NTLMAUTH_LISTENING_PORT/password_change"

$response = Invoke-RestMethod -Uri $url -Method Post -Body $eventJson -ContentType "application/json"

Write-Output($response)


