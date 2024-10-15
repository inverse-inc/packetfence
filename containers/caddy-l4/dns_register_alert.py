import json
import urllib.request
import socket
from flask import Flask, request, jsonify
import smtplib
from email.mime.text import MIMEText
import re
import os.path

app = Flask(__name__)

def send_mail(client_id, client_email, domain ):
    subject = f"[ PFaaS: {client_id} ] Error DNS resolution for {domain}"
    sender = "packetfenceaas@gmail.com"
    if client_email == None:
        client_email = "dl-Inverse-All@akamai.com"
    recipients = [client_email, "dl-Inverse-All@akamai.com"]

    gmail_smtp_password=os.environ.get('GMAIL_SMTP_PASSWORD')
    body = """
    <html>
    <body>
        <p>Hi!</p>
        <p>The domain <b> {domain} </b> failed to resolve. Kindly create a DNS entry and try again.</p>
    </body>
    </html>
    """
    body = body.format(domain=domain)
    msg = MIMEText(body, 'html')
    msg['Subject'] = subject
    msg['From'] = sender
    msg['To'] = ', '.join(recipients)
    with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp_server:
        smtp_server.login(sender, gmail_smtp_password)
        smtp_server.sendmail(sender, recipients, msg.as_string())
    print("Message sent!")

def find_email(fqdn):
    data = api("apps/tls/automation/policies/")
    # Loop through the data and print emails for the matching subject
    for entry in data:
        if fqdn in entry.get("subjects", []):
            if entry.get("issuers", []):
                return entry["issuers"][0]["email"]
    return None  # Return None if no matching subject or email is found

def is_fqdn_resolvable(domain):
    """
    This function checks if a given FQDN can be resolved by DNS.
    
    Args:
    fqdn (str): The Fully Qualified Domain Name to be checked.
    
    Returns:
    bool: True if the FQDN can be resolved, False otherwise.
    """
    try:
        # Attempt to resolve the FQDN to an IP address
        socket.gethostbyname(domain)
        return True
    except socket.gaierror:
        # If an error occurs, the FQDN is not resolvable
        return False

def api(path='', method='GET', string=None, data=None):
    base_url = 'http://localhost:2019/config/'

    if string:
        data = string.encode('utf-8')

    elif data:
        data = json.dumps(data, indent=2).encode('utf-8')

    if data:
        req = urllib.request.Request(base_url + path, data=data, method=method)

    else:
        req = urllib.request.Request(base_url + path, method=method)

    req.add_header('Content-Type', f'application/json')

    try:
        with urllib.request.urlopen(req) as response:
            r = response.read().decode('utf-8')

            if response.status != 200:
                print(f'{path} ({response.status=})')
                return dict(message=f'Error HTTP Status {response.status}', path=path)

            if len(r) == 0:
                return dict(message=response.msg, path=path)

            return json.loads(r)

    except urllib.error.HTTPError as e:
        # status=500 returned for PUT value and other configuration errors
        return dict(message=str(e), path=path)

    except json.decoder.JSONDecodeError as e:
        return dict(message=str(e), path=path)

    return dict(message='unknown error', path=path)

# Function to find the ID by FQDN (same as before)
def find_id_by_fqdn_recursive(data, fqdn_to_find):
    if isinstance(data, dict):
        for key, value in data.items():
            if key == 'fqdn' and value == fqdn_to_find:
                return data.get('id', None)
            result = find_id_by_fqdn_recursive(value, fqdn_to_find)
            if result:
                return result
    elif isinstance(data, list):
        for item in data:
            result = find_id_by_fqdn_recursive(item, fqdn_to_find)
            if result:
                return result
    return None

# Reading the JSON file
def load_data_from_json(file_path='/srv/vars/lb_client_vars.json'):
    with open(file_path, 'r') as f:
        data = json.load(f)
    return data



@app.route('/check', methods=['GET'])
def check_domain():
    # Get the domain parameter from the query string
    domain = request.args.get('domain')
    
    if domain is None:
        return jsonify({"error": "Domain parameter is missing"}), 400
        
    if is_fqdn_resolvable(domain):
        return jsonify({"domain": domain, "status": "allowed"}), 200
    else:
        client_email=find_email(domain)
        client_id = find_id_by_fqdn_recursive(load_data_from_json(), "matei1.mateiparent.packetfence.net")
        send_mail(client_id, client_email, domain)
        return jsonify({"domain": domain, "status": "not allowed"}), 404


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5555)
