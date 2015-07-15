##########################################################################################
#Powershell script to unregister disabled Active Directory account based on the UserName.#
##########################################################################################

Get-EventLog -LogName Security -InstanceId 4725 |
   Select ReplacementStrings,"Account name"|
   % {
    $url = "https://@IP_PACKETFENCE:9090/"
    $username = "admin" # Username for the webservice
    $password = "admin" # Password for the webservice
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $command = '{"jsonrpc": "2.0", "method": "unreg_node_for_pid", "params": ["pid", "'+$_.ReplacementStrings[0]+'"]}'

    $bytes = [System.Text.Encoding]::ASCII.GetBytes($command)
    $web = [System.Net.WebRequest]::Create($url)
    $web.Method = "POST"
    $web.ContentLength = $bytes.Length
    $web.ContentType = "application/json-rpc"
    $web.Credentials = new-object System.Net.NetworkCredential($username, $password)
    $stream = $web.GetRequestStream()
    $stream.Write($bytes,0,$bytes.Length)
    $stream.close()
    
    $reader = New-Object System.IO.Streamreader -ArgumentList $web.GetResponse().GetResponseStream()
    $reader.ReadToEnd()
    $reader.Close()
   }
