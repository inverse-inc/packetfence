PacketFence Fedora Dogtag integration
====================================

This is a work in progress.
The current status is that it's possible to enroll a certificate using the pki provider, but changes must be made to the dogtag server to allow "unauthenticated" scep usage, otherwise the service is single use only (i.e. PacketFence will only ever be able to enroll a single certificate).

This has been tested on Fedora 25 running Dogtag 10.3.
    
Configuring the Dogtag server
============================

After installing Dogtag (cf http://pki.fedoraproject.org/wiki/Quick_Start) follow the instructions to setup the CA.
See http://pki.fedoraproject.org/wiki/CA_Admin_Setup for the configuration of the CA admin, which is required.

You will need to import the CA admin certificate into your browser, as the admin GUI requires certificate authentication. In my testing Firefox has proven to be the only reliable browser for that as Chrome and Safari just throw up a TLS error on connecting to the GUI.
Follow the instructions to export the CA Admin Certificate to pem and import it into Firefox in Preferences > Advanced > Certificates.


Next, copy the files contained in this directory to the following directories: 

/var/lib/pki/pki-tomcat/ca/profiles/ca/caRADIUSServerCert.cfg
/var/lib/pki/pki-tomcat/ca/profiles/ca/caRADIUSClientCert.cfg
/var/lib/pki/pki-tomcat/ca/profiles/ca/caRouterCert.cfg
/etc/pki/pki-tomcat/ca/CS.cfg

and reboot for good measure.

This will create two certificate profiles for RADIUS servers and clients, and will disable the ip based authentication for scep enrollment.
You will have to configure iptables rules to ensure that only the PacketFence server is allowed to connect to the CA service running on ports 8443 and 8080 which is left as an exercise to the reader.

Once you have configured the CA on Dogtag, get a copy of the CA cert on the PacketFence server: 

(example)
# sscep getca -u http://dogtag.inverse.local:8080/ca/cgi-bin/pkiclient.exe -c /usr/local/pf/raddb/certs/dogtag_ca.pem

This will allow you to configure the Dogtag PKI provider in PacketFence.

You will also need to get a RADIUS server cert signed by the CA. 
That can be accomplished from the dogtag GUI where you will have to paste the CSR and then sign it with the CA.
