##########################################################################################
# Powershell script to audit and notify account changes from Active Directory.           #
#                                                                                        #
# See:                                                                                   #
#  https://www.packetfence.org/doc/PacketFence_Installation_Guide.html#_nt_key_caching   #
#                                                                                        #
# Minimum Requirements:                                                                  #
#    Windows 2008 R2, Powershell 3.5 or later                                            #
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

$domainID = ""              # your domain identifier in domain.conf
$max_events_per_batch = 10  # change this to a larger value if you have more than 10 password change / resets per 10 second. ideal value is: peak password change/reset events per 10 second + 10.

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

Write-Output($payloadJson)
