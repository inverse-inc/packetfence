#!/usr/bin/env python3
import requests
import csv
import urllib3
import argparse
import sys

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def get_auth_token(host, username, password):
    url = f"{host}/api/v1/login"
    payload = {"username": username, "password": password}
    r = requests.post(url, json=payload, verify=False)
    r.raise_for_status()
    return r.json().get("token")

def get_all_macs(host, token, limit, registered_only=False):
    url = f"{host}/api/v1/nodes"
    headers = {"Authorization": token}
    params = {"limit": limit}
    
    response = requests.get(url, headers=headers, params=params, verify=False)
    response.raise_for_status()
    
    data = response.json()
    items = data if isinstance(data, list) else data.get("items", [])
    
    mac_list = []
    for item in items:
        if registered_only and "status" in item and item.get("status") != "reg":
            continue
            
        mac = item.get("mac")
        if mac:
            mac_list.append(mac)
            
    return list(set(mac_list))

def export_nodes_to_csv(host, token, mac_list, filename, registered_only=False):
    fieldnames = [
        "mac", "status", "autoreg", "bypass_role", 
        "computername", "regdate", "unregdate", "notes", "role",
        "bandwidth_balance", "bypass_vlan", "bypass_acls", "voip", "ip"
    ]
    
    headers = {"Authorization": token}
    total = len(mac_list)
    exported_count = 0
    
    with open(filename, mode='w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter=';')
        writer.writeheader()
        
        for index, mac in enumerate(mac_list, 1):
            try:
                url = f"{host}/api/v1/node/{mac}"
                r = requests.get(url, headers=headers, verify=False)
                r.raise_for_status()
                
                node_data = r.json().get("item", {})
                
                if registered_only and node_data.get("status") != "reg":
                    if index % 100 == 0 or index == total:
                        print(f"Progress: {index} / {total} nodes processed... (Exported: {exported_count})")
                    continue
                
                row = {
                    "mac": node_data.get("mac"),
                    "status": node_data.get("status"),
                    "autoreg": node_data.get("autoreg"),
                    "bypass_role": node_data.get("bypass_role_id") or node_data.get("bypass_role"),
                    "computername": node_data.get("computername"),
                    "regdate": node_data.get("regdate"),
                    "unregdate": node_data.get("unregdate"),
                    "notes": node_data.get("notes"),
                    "role": node_data.get("category"),
                    "bandwidth_balance": node_data.get("bandwidth_balance"),
                    "bypass_vlan": node_data.get("bypass_vlan"),
                    "bypass_acls": node_data.get("bypass_acls"),
                    "voip": node_data.get("voip"),
                    "ip": node_data.get("ip")
                }
                
                clean_row = {k: (str(v) if v is not None else "") for k, v in row.items()}
                writer.writerow(clean_row)
                exported_count += 1
                
                if index % 100 == 0 or index == total:
                    print(f"Progress: {index} / {total} nodes processed... (Exported: {exported_count})")
                    
            except Exception as e:
                print(f"Error fetching node {mac}: {e}")
                
    return exported_count

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="PacketFence Node Export to CSV")
    parser.add_argument("-H", "--host", required=True, help="PacketFence Host (ex. https://ip.ip.ip.ip:1443)")
    parser.add_argument("-U", "--username", required=True, help="API Username")
    parser.add_argument("-P", "--password", required=True, help="API Password")
    parser.add_argument("-O", "--output", required=True, help="Name of output CSV file")
    parser.add_argument("-L", "--limit", type=int, default=500000, help="Paging limit (default: 500000)")
    
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("-A", "--all", action="store_true", help="Export all nodes (registered and unregistered)")
    group.add_argument("-R", "--registered-only", action="store_true", help="Only export nodes with 'reg' status")
    
    args = parser.parse_args()
    host = args.host.rstrip('/')

    try:
        print(f"Authenticate on PacketFence API ({host})...")
        token = get_auth_token(host, args.username, args.password)
        print("Authentication Success!\n")
        
        mode = "REGISTERED ONLY" if args.registered_only else "ALL NODES"
        print(f"Selected export mode: {mode}\n")
        
        print("Getting MAC addresses list...")
        mac_list = get_all_macs(host, token, args.limit, args.registered_only)
        print(f"Total unique MAC addresses found for processing: {len(mac_list)}\n")
        
        print("Starting detailed download and CSV generation (this will take some time)...")
        exported_total = export_nodes_to_csv(host, token, mac_list, args.output, args.registered_only)
        
        print(f"\nExporting Success: {args.output}")
        print(f"Total nodes exported to CSV: {exported_total}")
        
    except requests.exceptions.RequestException as e:
        print(f"Network Communication Fail: {e}")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\nInterrupted by User.")
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected Error: {e}")
        sys.exit(1)
