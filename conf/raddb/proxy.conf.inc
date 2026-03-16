# Eduroam integration is not configured

realm default {

}
realm local {

}
realm null {

}


realm eduroam.default {

}

realm eduroam.local {

}

realm eduroam.null {

}





# pfacct configuration

realm pfacct {
    acct_pool = pfacct_pool
    nostrip
}

home_server_pool pfacct_pool {
    home_server = pfacct_local
}

home_server pfacct_local {
    type = acct
    ipaddr = 127.0.0.1
    port = 1813
    secret = 'OGVmNzA5OTdmZWRiZTNkYzJkMjk3YzU3'
    src_ipaddr = 172.105.6.121
}



