##########################################################################################
#Powershell script to unregister disabled Active Directory account based on the UserName.#
##########################################################################################
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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


