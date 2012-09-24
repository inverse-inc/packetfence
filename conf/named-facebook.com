; This file is generated from a template at /usr/local/pf/conf/named-registration.ca
; Any changes made to this file will be lost on restart

; Registration network DNS configuration
; This file is manipulated on PacketFence's startup before being given to named
$ORIGIN facebook.com.
$TTL 1
@ IN SOA pf-dev3.facebook.com. pf.pf-dev3.facebook.com. (
    2009020902  ; serial
    10800       ; refresh
    3600        ; retry
    604800      ; expire
    86400       ; default_ttl
)
	IN NS www.facebook.com.

www     IN      A       69.171.234.21
www	IN	A	69.171.228.70
graph	IN	A	66.220.149.93
s-static.ak IN  A	23.11.2.110
*	     IN	     A 	     %%A_blackhole%%
