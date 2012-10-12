; This file is generated from a template at /usr/local/pf/conf/named-registration.ca
; Any changes made to this file will be lost on restart

; Registration network DNS configuration
; This file is manipulated on PacketFence's startup before being given to named
$ORIGIN google.com.
$TTL 1
@ IN SOA %%hostname%%. %%incharge%% (
    2009020902  ; serial
    10800       ; refresh
    3600        ; retry
    604800      ; expire
    86400       ; default_ttl
)
	IN NS accounts.google.com.
        IN A %%A_blackhole%%

accounts     IN      A       74.125.142.84
*	     IN	     A 	     %%A_blackhole%%
