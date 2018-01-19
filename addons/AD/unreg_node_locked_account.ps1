##########################################################################################
#Powershell script to unregister disabled Active Directory account based on the UserName.#
##########################################################################################
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Get-EventLog -LogName Security -InstanceId 4740 |
   Select ReplacementStrings,"Account name"|
   % {
    $url = "https://@IP_PACKETFENCE:9090/"
    $username = "admin" # Username for the webservice
    $password = "admin" # Password for the webservice

    $netbiosdomain = $env:userdomain
    $fqdndomain = $env:userdnsdomain.ToLower()
    $nodomadusername = $_.ReplacementStrings[0]
    $netbiosadusername = $netbiosdomain + "\\" + $nodomadusername
    $upnadusername = $nodomadusername + "@" + $fqdndomain
    $spnusername = "host/" + ($nodomadusername -replace "\$" , "") + "." + $fqdndomain
    $adusernames = @($nodomadusername, $netbiosadusername, $upnadusername, $spnusername)

    foreach ($adusername in $adusernames) {
       [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
       $command = '{"jsonrpc": "2.0", "method": "unreg_node_for_pid", "params": ["pid", "'+$adusername+'"]}'

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
   }
