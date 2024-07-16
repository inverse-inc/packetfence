import os


def generate_empty_conf():
    path = '/usr/local/pf/var/conf/'
    os.makedirs(path, exist_ok=True)
    with open('/usr/local/pf/var/conf/default.conf', 'w') as file:
        file.write("\n")


def generate_resolv_conf(dns_name, dns_servers_string):
    with open('/etc/resolv.conf', 'w') as file:
        file.write(f"\n")
        file.write(f"search {dns_name}\n")
        file.write("\n")
        file.write("options timeout:1\n")
        file.write("options attempts:1\n")
        file.write("\n")

        dns_servers = dns_servers_string.split(",")
        for dns_server in dns_servers:
            file.write(f"nameserver {dns_server}\n")
        file.write("\n")


def generate_hosts_entry(ip, hostname):
    with open('/etc/hosts', 'a') as file:
        file.write(f"\n")
        file.write(f"{ip}    {hostname}")
        file.write("\n")
