; This file is generated from a template at /usr/local/pf/conf/named-registration.ca
; Any changes made to this file will be lost on restart

; Registration network DNS configuration
; This file is manipulated on PacketFence's startup before being given to named
$ORIGIN facebook.com.
$TTL 1
@ IN SOA %%hostname%%. %%incharge%% (
    2009020902  ; serial
    10800       ; refresh
    3600        ; retry
    604800      ; expire
    86400       ; default_ttl
)
	IN NS www.facebook.com.
        IN A %%A_blackhole%%

www     IN	A	66.220.146.94
www     IN	A	66.220.146.101
www     IN      A       66.220.149.88
www     IN      A       66.220.149.93
www     IN      A       66.220.149.94
www     IN      A       66.220.153.74
www     IN      A       69.63.190.74
www     IN      A       69.171.224.32
www     IN      A       69.171.228.70
www     IN      A       69.171.228.74
www     IN      A       69.171.229.16
www     IN      A       69.171.234.21
www     IN      A       69.171.234.37
www     IN      A       69.171.237.16
www     IN      A       69.171.237.32
graph	IN	A	66.220.149.93
graph   IN	A	66.220.147.93
graph 	IN	A	69.63.189.71
s-static.ak IN  A	23.11.2.110
*	     IN	     A 	     %%A_blackhole%%
