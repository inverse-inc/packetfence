#! /usr/bin/python3
import os.path
import argparse
from subprocess import run, CalledProcessError
from jwt import JWT, jwk_from_pem
from cryptography.hazmat.primitives.serialization import load_pem_private_key
from cryptography.hazmat.backends import default_backend
import time
from base64 import b64encode
import requests
import smtplib
from email.mime.text import MIMEText
import re


def b64encodestr(string):
    return b64encode(string.encode("utf-8")).decode()


def update_secrets(namespace, secret, key, val):
    b64val = b64encodestr(val)
    retry_count = 0
    while retry_count < 5:
        cmd = f"""kubectl --namespace {namespace} patch secret {secret} -p='{{"data":{{"{key}": "{b64val}"}}}}'"""
        result = run(cmd, shell=True)
        if result.returncode==0:
            print(f"OK, update was succesfull:  namespace {namespace}, k8s secret {secret}, key {key} ")
            return result
        else:
            print("Retrying in 5 seconds...")
            time.sleep(5)  # Wait for 5 seconds before retrying
            retry_count += 1
    raise RuntimeError(f"Failed to update the secret {secret} on namspace {namespace} key {key}   after 5 attempts.")


def is_private_key(pem_file_path):
    try:
        with open(pem_file_path, 'rb') as pem_file:
            load_pem_private_key(pem_file.read(), password=None, backend=default_backend())
        return True
    except Exception:
        return False


def generate_jwt_token(pem, app_id):


    retry_count = 0
    while retry_count < 5:
        try:
            if not os.path.isfile(pem):
                raise RuntimeError(f"PEM file does not exist {pem}")

            if not is_private_key(pem):
                raise RuntimeError(f"PEM file does not contain a private key {pem}")

            with open(pem, 'rb') as pem_file:
                signing_key = jwk_from_pem(pem_file.read())

            payload = {
                'iat': int(time.time()),
                'exp': int(time.time()) + 600,
                'iss': app_id
            }

            jwt_instance = JWT()
            encoded_jwt = jwt_instance.encode(payload, signing_key, alg='RS256')
            return encoded_jwt

        except Exception as e:
            print("Error:", e)
            print("Retrying in 5 seconds...")
            time.sleep(5)  # Wait for 5 seconds before retrying
            retry_count += 1
    # If 5 attempts fail, raise an error
    raise RuntimeError("Failed to generate jwt token after 5 attempts.")

def  generate_token(jwt_token, org_github_apps_id, github_client_repository_name):
    # Set the headers
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": "Bearer " + jwt_token,
        "X-GitHub-Api-Version": "2022-11-28"
    }

    # Set the data payload
    data = {
        "repositories": [f"{github_client_repository_name}"]
    }

    # Set the URL
    url = f"https://api.github.com/app/installations/{ org_github_apps_id }/access_tokens"

    retry_count = 0
    while retry_count < 5:
        try:
            # Send the POST request
            response = requests.post(url, headers=headers, json=data)
            response.raise_for_status()  # Raise an exception for HTTP errors
            result = response.json()
            return result['token'] # Return the token itself
        except requests.exceptions.RequestException as e:
            print("Error:", e)
            print("Retrying in 5 seconds...")
            time.sleep(5)  # Wait for 5 seconds before retrying
            retry_count += 1

    # If 5 attempts fail, raise an error
    raise RuntimeError("Failed to generate token after 5 attempts.")



def send_mail( gmail_smtp_password, error, client_name, client_email, k8s_namespace_name, k8s_secret_name ):
    subject = "PacketFence Cloud NAC: Error token update"
    sender = "packetfenceaas@gmail.com"
    recipients = [client_email, "i.stegarescu@yahoo.com"]
    body = """
    <html>
    <body>
        <p>Hi {client_name}!</p>
        <p>The next error was encountered during update of token: </p>
        <p><b>{error}</b> </p>
        </br>
        <p>Other informations:</p>
            <p>Client namespace:  {k8s_namespace_name}</p>
            <p>Client secret name: {k8s_secret_name}</p>
    </body>
    </html>
    """
    body = body.format(client_name=client_name, error=error, k8s_namespace_name=k8s_namespace_name, k8s_secret_name=k8s_secret_name )
    msg = MIMEText(body, 'html')
    msg['Subject'] = subject
    msg['From'] = sender
    msg['To'] = ', '.join(recipients)
    with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp_server:
        smtp_server.login(sender, gmail_smtp_password)
        smtp_server.sendmail(sender, recipients, msg.as_string())
    print("Message sent!")


def email_type(value):
    RE_EMAIL = re.compile(r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$")
    if not RE_EMAIL.match(value):
        raise argparse.ArgumentTypeError(f"'{value}' is not a valid email")
    return value

def main():
    parser = argparse.ArgumentParser(description="Update token for each client")
    parser.add_argument("--private_key_file", default=os.environ.get('PRIVATE_KEY_FILE'), help="Path to private key file")
    parser.add_argument("--github_org_apps_id", default=os.environ.get('GITHUB_ORG_APPS_ID'), type=int, help="GitHub organization apps ID")
    parser.add_argument("--github_installed_apps_id", default=os.environ.get('GITHUB_INSTALLED_APPS_ID'), type=int, help="GitHub installed apps ID")
    parser.add_argument("--github_client_repository_name", default=os.environ.get('GITHUB_CLIENT_REPOSITORY_NAME'), help="GitHub client repostory name")
    parser.add_argument("--k8s_namespace_name", default=os.environ.get('K8S_NAMESPACE_NAME'), help="Kubernetes namespace name")
    parser.add_argument("--k8s_secret_name", default=os.environ.get('K8S_SECRET_NAME'), help="Kubernetes secret name")
    parser.add_argument("--gmail_smtp_password", default=os.environ.get('GMAIL_SMTP_PASSWORD'), help="Gmail SMTP secret")
    parser.add_argument("--client_name", default=os.environ.get('CLIENT_NAME'), help="Client Name")
    parser.add_argument("--client_email", default=os.environ.get('CLIENT_EMAIL'), type=email_type,  help="Client email")
    args =  parser.parse_args()

    private_key_file=args.private_key_file
    github_org_apps_id=args.github_org_apps_id
    github_installed_apps_id=args.github_installed_apps_id
    github_client_repository_name=args.github_client_repository_name
    k8s_namespace_name=args.k8s_namespace_name
    k8s_secret_name=args.k8s_secret_name
    gmail_smtp_password=args.gmail_smtp_password
    client_name=args.client_name
    client_email=args.client_email

    if not private_key_file or not github_org_apps_id or not github_installed_apps_id or not k8s_namespace_name or not k8s_secret_name or not github_client_repository_name:
        exit(parser.print_usage())

    try:
        jwt_token = generate_jwt_token(private_key_file, github_org_apps_id)
    except Exception as e:
        error=f"Error: {e}"
        print(error)
        send_mail( gmail_smtp_password, error, client_name, client_email, k8s_namespace_name, k8s_secret_name )
        exit(1)


    try:
        fine_graned_token = generate_token(jwt_token, github_installed_apps_id, github_client_repository_name)
    except RuntimeError as e:
        error=f"Error: {e}"
        print(error)
        send_mail( gmail_smtp_password, error, client_name, client_email, k8s_namespace_name, k8s_secret_name )
        exit(1)
# update the github_token
    try:
        k8s_secret_key="github_token_key"
        update_secrets(k8s_namespace_name, k8s_secret_name, k8s_secret_key, fine_graned_token)
    except Exception as e:
        error=f"Error update k8s secret on { k8s_namespace_name }: {e}"
        print(error)
        send_mail( gmail_smtp_password, error, client_name, client_email, k8s_namespace_name, k8s_secret_name )
        exit(1)

# update the github_token
    try:
        k8s_secret_key="netrc_key"
        netrc_value=f"machine github.com login inversebot password {fine_graned_token}"
        update_secrets(k8s_namespace_name, k8s_secret_name, k8s_secret_key, netrc_value)
    except Exception as e:
        error=f"Error update k8s secret on { k8s_namespace_name }: {e}"
        print(error)
        send_mail( gmail_smtp_password, error, client_name, client_email, k8s_namespace_name, k8s_secret_name )
        exit(1)

if __name__ == '__main__':
    main()