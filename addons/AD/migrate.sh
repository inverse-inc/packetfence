
REALM=$(grep default_realm /etc/krb5.conf | awk '{print $3}') 
WORKGROUP=$(grep workgroup /etc/samba/smb.conf | awk '{print $3}')
SERVER=$(grep admin_server /etc/krb5.conf | head -1 | awk '{print $3}')
NAMESERVER=$(grep nameserver /etc/resolv.conf | head -1 | awk '{print $2}')

echo "Configuring realm : $REALM"
echo "Configuring workgroup : $WORKGROUP"
echo "Configuring with AD server : $SERVER"
echo "Configuring with nameserver : $NAMESERVER"

echo "CAUTION: The following information will end up in clear text in the PacketFence configuration files. We suggest you create another account to bind this server. This account needs to have the rights to bind a new server on the domain."
echo "What is the username to bind this server on the domain"
read user

echo "Password:"
read -s password

echo "User : $user"
echo "Password : $password"

