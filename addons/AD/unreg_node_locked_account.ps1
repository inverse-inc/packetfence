#########################################################################################
#Powershell script to unregister locked Active Directory account based on the UserName.#
#########################################################################################

Get-EventLog -LogName Security -InstanceId 4725 |
   Select ReplacementStrings,"Account name"|
   % {
    $url = "https://@IP_PACKETFENCE:9090/"
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    $command = '{"jsonrpc": "2.0", "method": "unreg_node_for_pid", "params": [{"pid": "'+$_.ReplacementStrings[0]+'"}]}'


	$bytes = [System.Text.Encoding]::ASCII.GetBytes($command)
	$web = [System.Net.WebRequest]::Create($url)
	$web.Method = "POST"
	$web.ContentLength = $bytes.Length
	$web.ContentType = "application/json-rpc"
	$stream = $web.GetRequestStream()
	$stream.Write($bytes,0,$bytes.Length)
	$stream.close()

	$reader = New-Object System.IO.Streamreader -ArgumentList$web.GetResponse().GetResponseStream()
	$reader.ReadToEnd()
	$reader.Close()
   }

