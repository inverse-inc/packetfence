import requests
import json
import nacl.encoding
import nacl.secret
import argparse
import sys

SSL_VERIFY = True

def api_request(method, endpoint, data = None):

    headers = {'content-type': 'application/json'}
    try:
        r = requests.request(method, server_url + endpoint, data=data, headers=headers, verify=SSL_VERIFY)
        r.raise_for_status()
    except requests.exceptions.RequestException as e:
        sys.exit(f'error: {e}')
    except requests.exceptions.HTTPError as e:
        sys.exit(f'error: {e}')

    return r.json()

def api_read_secret(data):

    method = 'POST'
    endpoint = '/api-key-access/secret/'
    encrypted_secret = api_request(method, endpoint, data)

    # decrypt step 1: Decryption of the encryption key
    crypto_box = nacl.secret.SecretBox(api_key_secret_key, encoder=nacl.encoding.HexEncoder)
    encryption_key = crypto_box.decrypt(nacl.encoding.HexEncoder.decode(encrypted_secret['secret_key']),
                                        nacl.encoding.HexEncoder.decode(encrypted_secret['secret_key_nonce']))

    # decrypt step 2: Decryption of the secret
    crypto_box = nacl.secret.SecretBox(encryption_key, encoder=nacl.encoding.HexEncoder)
    decrypted_secret = crypto_box.decrypt(nacl.encoding.HexEncoder.decode(encrypted_secret['data']),
                                        nacl.encoding.HexEncoder.decode(encrypted_secret['data_nonce']))

    return json.loads(decrypted_secret)

def return_data(return_value, decrypted_secret):
    if return_value == "username":
        return decrypted_secret['application_password_username']
    elif return_value == "password":
        return decrypted_secret['application_password_password']
    elif return_value == "title":
        return decrypted_secret['application_password_title']
    elif return_value == "password_notes":
        return decrypted_secret['application_password_notes']
    elif return_value == "all":
        return json.dumps(decrypted_secret)
    else:
        return f"The condition does not correspond"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--return_value', type=str,
                    choices=['all', 'password', 'username', 'title' , 'password_notes'],
                    default= 'all',
                    help='all: Return all options\n'           
                        'password: return password(application_password_password)\n'
                        'password_notes: return password_notes(application_password_notes)\n'
                        'username: return username(application_password_username)\n'
                        'title: return title secret\n')
    parser.add_argument("--api_key_id", required=True,  help="Please enter api_key_id", type=str)
    parser.add_argument("--api_key_secret_key", required=True,  help="Please enter api_key_secret_key", type=str)
    parser.add_argument("--secret_id", required=True,  help="Please enter secret_id", type=str)
    parser.add_argument("--server_url", required=False, default='https://psono.inverse.ca/server',  help="Please enter server url, default(https://psono.inverse.ca/server)", type=str)

    args = parser.parse_args()
    return_value = args.return_value
    api_key_id = args.api_key_id
    global api_key_secret_key
    api_key_secret_key = args.api_key_secret_key
    secret_id = args.secret_id
    global server_url
    server_url = args.server_url

    data = json.dumps({
        'api_key_id': api_key_id,
        'secret_id': secret_id
    })

    decrypted_data = api_read_secret(data)

    value = return_data(return_value, decrypted_data)

    print(value)


if __name__ == '__main__':
    main()
