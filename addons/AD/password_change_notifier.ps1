##########################################################################################
# Powershell script to audit and notify a password change on an Active Directory.        #
##########################################################################################
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

$base_url = "https://#PACKETFENCE_IP:9999"
$username = ""         # Username for the webservice, change to your own username.
$password = ""         # Password for the webservice, change to your own password.

$token_url = $base_url + "/api/v1/login"
$password_notifier_url = $base_url + "/api/v1/ntlm/password_change"

$credential = @{ "username" = $username; "password" = $password }
$credJson = $credential| ConvertTo-Json
$token_response = Invoke-RestMethod -Uri $token_url -Method Post -Body $credJson -ContentType "application/json"
$token = $token_response.token

$eventTypeID = 4724
$events = Get-WinEvent -MaxEvents 10  -FilterHashTable @{ Logname = "Security"; ID = $eventTypeID }

$eventArr = @()
foreach ($event in $events)
{
    $e = @{ }
    $xmlObject = [xml]$event.ToXml()
    $e['recordID'] = $event.RecordId
    $e['eventTime'] = $event.TimeCreated
    $e['eventTypeID'] = $event.Id

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
$response = Invoke-RestMethod -Uri $password_notifier_url -Method Post -Body $eventJson -ContentType "application/json" -Headers @{ "Authorization" = $token }

Write-Output($response)
