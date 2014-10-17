PEAP/MSCHAPV2 on Active Directory without ntlm_auth

The goal of this procedure is to remove ntlm_auth in freeradius configuration and use a ldap attribute that contain the NTHASH of the user´s password.

In order to make it work we need to update the Active Directory schema to add a new attribute.

In this how-to we use a Windows server 2008 R2 and the baseDN is dc=inverse,dc=inc and we use PacketFence 4.4.

# Schema update

To register the Active Directory Schema Editor, open a command prompt, type regsvr32 schmmgmt.dll and press [Enter]. When you do, you'll see a RegSrv32 dialog box appear displaying the message “DllRegisterServer in schmmgmt.dll succeeded”. Once the schmmgmt.dll is registered for use on the server, you can then use it as an MMC snap-in.

To install the Active Directory Editor snap-in, click Start | Run and enter MMC /a in the Run dialog box. This opens a blank MMC console in author mode. Maximize the Console Root window to make the MMC easier to view and work with. Next, select Add/Remove Snap-In from the Console menu. When the Add/Remove Snap-In window appears, click Add. Doing so will display the Add Standalone Snap-In window, which contains a list of available snap-ins that you can use to create your MMC.

Scroll through the list of snap-ins until you see Active Directory Schema. Select it and then click Add. Click Close to close the Add Standalone Snap-In dialog box and then click OK to close the Add/Remove Snap-In dialog box. You'll then see the Active Directory Schema MMC appear, as shown in Figure A.

You can create a new attribute by clicking right on Attributes, a new window appear to fill out the information for your new attribute.

```
Common Name: ntPassword
LDAP Display Name: ntPassword
Unique x500 Object ID: 1.3.6.1.4.1.2964.2.1
Description: NTHASH Password

Syntax: Case Sensitive String
```

And validate

Now go in Classes and add ntPassword attribute as an optional attribute for the user class (Do the same for computer).

# Security

Because nthash is considered unsecured we must add security on Active Directory in order to make only one user able to write and read this attribute.

First create a new user in Active Directory (it will be used to update the nthash attribute and to connect to AD from freeradius) like PacketFenceAdmin.
(The dn of this user is CN=PacketFenceAdmin,CN=Users,DC=inverse,dc=inc)

Now in the Active Directory Schema mmc console, right click on User class (you will have to do the same thing for Computer class) then go on Default Security, Advanced and add these permissions:

```
Allow PacketFenceAdmin to Read ntPassword and write ntPassword
Allow Administrator to Read ntPassword and write ntPassword
Deny everyone to Read ntPassword and Write ntPassword
```

# Installation

```
Copy HashingPasswordFilter.dll in c:\windows\system32\
Copy HashingPasswordFilter.ini in c:\ProgramData\ (C:\Documents and Settings\All Users\Application Data for windows 2003 server) and edit the file:
```

```
[Main]
;LDAP server
ldapServer=127.0.0.1
;DN and password of an AD user that can write the “hashedPassword” field
ldapAdminBindDn=CN=PacketFenceAdmin,CN=Users,DC=inverse,DC=inc
ldapAdminPasswd=password
;LDAP query to find your AD users
ldapSearchBaseDn=DC=inverse,DC=inc
;name and password of a local account to use to run the sync application
processUser=Administrator
;NTHASH attribute to update in AD
ntHashAttribute=ntPassword
```

Launch regedit and edit the HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa\Notification Packages then add HashingPasswordFilter at the end of the list.

Then restart the server.

# First test

Once the server reboot, go in Active Directory Users and Computers and change a password of a user (Robert).
Then open c:\ProgramData\HashingPasswordFilter.log, you will see that Robert´s password has been changed.
Then now launch adsiedit.msc and edit the robert user, you will see the ntPassword attribute that contains the password´s NTHASH.


# Freeradius configuration

First we have to configure the ldap connection, in /usr/local/pf/raddb/modules edit ldap file and add ad_user and ad_computer configuration:

```
ldap ad_user {
    server = "ad2008"
    identity = "CN=PacketFenceAdmin,CN=Users,DC=inverse,DC=inc"
    password = password
    basedn = "dc=inverse,dc=inc"
    filter = "(sAMAccountName=%{%{Stripped-User-Name}:-%{User-Name}})"
    ldap_connections_number = 5
    timeout = 4
    timelimit = 3
    net_timeout = 1
    tls {
        # Set this to 'yes' to use TLS encrypted connections
        # to the LDAP database by using the StartTLS extended
        # operation.
        #           
        # The StartTLS operation is supposed to be
        # used with normal ldap connections instead of
        # using ldaps (port 689) connections
        start_tls = no

        # cacertfile    = /path/to/cacert.pem
        # cacertdir        = /path/to/ca/dir/
        # certfile        = /path/to/radius.crt
        # keyfile        = /path/to/radius.key
        # randfile        = /path/to/rnd

        #  Certificate Verification requirements.  Can be:
        #    "never" (don't even bother trying)
        #    "allow" (try, but don't fail if the cerificate
        #        can't be verified)
        #    "demand" (fail if the certificate doesn't verify.)
        #
        #    The default is "allow"
        # require_cert    = "demand"
    }

    dictionary_mapping = ${confdir}/ldap.attrmap
    edir_account_policy_check = no
    keepalive {
        # LDAP_OPT_X_KEEPALIVE_IDLE
        idle = 60

        # LDAP_OPT_X_KEEPALIVE_PROBES
        probes = 3

        # LDAP_OPT_X_KEEPALIVE_INTERVAL
        interval = 3
    }
}

ldap ad_computer {
    server = "ad2008"
    identity = "CN=Administrator,CN=Users,DC=inverse,DC=inc"
    password = password
    basedn = "dc=inverse,dc=inc"
    filter = "(servicePrincipalName=%{%{Stripped-User-Name}:-%{User-Name}})"
    ldap_connections_number = 5
    timeout = 4
    timelimit = 3
    net_timeout = 1
    tls {
        # Set this to 'yes' to use TLS encrypted connections
        # to the LDAP database by using the StartTLS extended
        # operation.
        #           
        # The StartTLS operation is supposed to be
        # used with normal ldap connections instead of
        # using ldaps (port 689) connections
        start_tls = no

        # cacertfile    = /path/to/cacert.pem
        # cacertdir        = /path/to/ca/dir/
        # certfile        = /path/to/radius.crt
        # keyfile        = /path/to/radius.key
        # randfile        = /path/to/rnd

        #  Certificate Verification requirements.  Can be:
        #    "never" (don't even bother trying)
        #    "allow" (try, but don't fail if the cerificate
        #        can't be verified)
        #    "demand" (fail if the certificate doesn't verify.)
        #
        #    The default is "allow"
        # require_cert    = "demand"
    }
    dictionary_mapping = ${confdir}/ldap.attrmap
    edir_account_policy_check = no
    keepalive {
        # LDAP_OPT_X_KEEPALIVE_IDLE
        idle = 60

        # LDAP_OPT_X_KEEPALIVE_PROBES
        probes = 3

        # LDAP_OPT_X_KEEPALIVE_INTERVAL
        interval = 3
    }
}
```

Note that you will probably receive a username attribute like that "INVERSE\Username" or "username@inverse.inc" in the radius request so you will have to add in radius
configuration the 2 realms (proxy.conf):

```
realm INVERSE {
strip
}

realm inverse.inc {
strip
}
```

Then edit /usr/local/pf/raddb/site-available/packetfence-tunnel and authorize section should be this one:

```
authorize {   
        suffix
        ntdomain

        ad_user
        if (ok) {
            update control {
                MS-CHAP-Use-NTLM-Auth := No
            }
        }
        if (notfound) {
            ad_computer
            if (ok) {
                update control {
                    MS-CHAP-Use-NTLM-Auth := No
                }
            }
        }
        eap {

                ok = return
        }
        files
####Activate local user eap authentication based on a specific SSID ####
## Set Called-Station-SSID with the current SSID
#        set.called_station_ssid
#        if (Called-Station-SSID == 'Secure-Wireless') {
## Disable ntlm_auth
#            update control {
#                MS-CHAP-Use-NTLM-Auth := No
#            }
## Check temporary_password table for local user
#            pflocal
#            if (fail || notfound) {
## Check temporary_password table with email and password for a sponsor registration
#                pfguest
#                if (fail || notfound) {
## Check temporary_password table with email and password for a guest registration
#                    pfsponsor
#                    if (fail || notfound) {
## Check activation table with phone number and PIN code
#                        pfsms
#                        if (fail || notfound) {
#                            update control {
#                               MS-CHAP-Use-NTLM-Auth := Yes
#                            }
#                        }
#                    }
#                }
#            }
#        }
        expiration
        logintime
}
```

# Hybrid mode

Because you will only have the new NTHASH when a user change his password or when a user is
created (Computer too) then you will not have all the NTHASH.

You have 2 solutions:

First one: use ntlm_auth in the case of ldap failled to retreive the NTHASH, in this case you just
have to configure the PacketFence server to join the domain and with the time you will use less ntlm_auth.

Second choice: Use something like fgdump (http://www.question-defense.com/2010/01/20/dumping-ntlm-hashs-from-windows-with-fgdump) to retreive all the NTHASH of your user and fill the information
in the ntPassword attribute of each users.

