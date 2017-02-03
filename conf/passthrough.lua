-- Update host on the fly

core.register_action("choose_backend", { 'http-req'}, function(txn)
    if txn.sf:req_fhdr("Host") == 'www.packetfence.org' then
        txn.set_var(txn,"req.host","www.cisco.com") -- Update host on the fly
    end
end)


-- Select backend based on Host header

core.register_action("select", { "http-req" }, function(txn) 
    local backend = nil
    if txn.sf:req_fhdr("Host") == 'www.packetfence.org' then -- TODO dynamic list based on ip of the portal and fqdn of the portal
        txn:set_var("req.action","proxy")
    end
end)
