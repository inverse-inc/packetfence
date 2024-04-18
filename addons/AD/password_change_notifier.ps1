##########################################################################################
# Powershell script to audit and notify account changes from Active Directory.           #
#                                                                                        #
# See:                                                                                   #
#  https://www.packetfence.org/doc/PacketFence_Installation_Guide.html#_nt_key_caching   #
#                                                                                        #
# Minimum Requirements:                                                                  #
#    Windows 2012 R2                                                                     #
#                                                                                        #
# Notifies PacketFence of AD Events:                                                     #
#    4723: Account password change                                                       #
#    4724: Account password reset                                                        #
#    4767: User account unlock                                                           #
#                                                                                        #
# Requires the variables:                                                                #
#    $base_url: the URL to the PacketFence API                                           #
#    $username: the PacketFence API username                                             #
#    $password: the PacketFence API password                                             #
#    $domainID: the unique PacketFence Domain identifier (one script per-domain)         #
##########################################################################################
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

$base_url = "https://#PACKETFENCE_IP:9999"
$username = ""              # Username for the API Frontend, change to your own username.
$password = ""              # Password for the API Frontend, change to your own password.
$domainID = ""              # your domain identifier in domain.conf
$max_events_per_batch = 10  # change this to a larger value if you have more than 10 password change / resets per 10 second. ideal value is: peak password change/reset events per 10 second + 10.

$token_url = $base_url + "/api/v1/login"
$password_notifier_url = $base_url + "/api/v1/ntlm/event-report"

$credential = @{ "username" = $username; "password" = $password }
$credJson = $credential| ConvertTo-Json
$token_response = Invoke-RestMethod -Uri $token_url -Method Post -Body $credJson -ContentType "application/json"
$token = $token_response.token

$eventTypeID = @(4723, 4724, 4767)

$events = Get-WinEvent -MaxEvents $max_events_per_batch  -FilterHashTable @{ Logname = "Security"; ID = $eventTypeID }

$eventArr = @()
foreach ($event in $events)
{
    $e = @{ }
    $xmlObject = [xml]$event.ToXml()
    $e['RecordID'] = $event.RecordId
    $e['EventTime'] = $event.TimeCreated
    $e['EventTypeID'] = $event.Id

    if ($xmlObject.Event.EventData.Data.Length -ge 0)
    {
        foreach ($entry in $xmlObject.Event.EventData.Data)
        {
            $e[$entry.Name] = $entry.InnerText
        }
    }
    $eventArr += $e
}
$payload = @{}
$payload['Domain'] = $domainID
$payload['Events'] = $eventArr
$payloadJson = $payload | ConvertTo-Json
$response = Invoke-RestMethod -Uri $password_notifier_url -Method Post -Body $payloadJson -ContentType "application/json" -Headers @{ "Authorization" = $token }

Write-Output($response)

Write-Output $payloadJson | out-file payload.json.txt
Write-Output $response | out-file response.txt
