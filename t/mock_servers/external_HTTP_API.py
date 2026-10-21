# If you are running your external HTTP auth server (for example, this script) on a PacketFence server,
# please make sure that you are configuring your authentication source using the appropriate hostname or IP.
# typically you need to use "containers-gateway.internal" or "100.64.0.1" instead of "127.0.0.1"
# because PacketFence services are now running inside containers using docker, and "127.0.0.1" refers to the
# loopback of the container, not the PacketFence server.

# When using external HTTP authentication source, PacketFence will take parameters such as username and password
# from Form Values. If the programming language you are using does not have a built-in method to extract POST fields,
# you might need to test and debug by specifying this header: "Content-Type: application/x-www-form-urlencoded"

from flask import Flask, request, jsonify

app = Flask(__name__)

RES_CODE_SUCCESS = 1
RES_CODE_FAILURE = 0


@app.route('/authenticate', methods=['POST'])
def authenticate():
    username, password, error = extract_credentials()

    if error:
        return jsonify(error), 400

    if username == 'test' and password == 'testing123':
        return jsonify({"result": RES_CODE_SUCCESS, "message": "ok"}), 200
    else:
        return jsonify({"result": RES_CODE_FAILURE, "message": "Unauthorized: bad username or password"}), 401


@app.route('/authorize', methods=['POST'])
def authorize():  # here is an example, we always return the same authorization data, implement your own logic here.
    response_data = {
        "access_duration": "1D",
        "access_level": "ALL",
        "sponsor": 1,
        "unregdate": "2030-01-01 00:00:00",
        "category": "default",
    }
    return jsonify(response_data), 200


def extract_credentials():
    try:
        if request.is_json:
            return None, None, {"result": RES_CODE_FAILURE, "message": "Invalid payload, form-urlencoded data required"}
        else:
            data = request.form

        username = data.get("username")
        password = data.get("password")

        if not username or not password:
            return None, None, {"result": RES_CODE_FAILURE, "message": "Invalid payload, missing username or password"}

        return username, password, None

    except Exception as e:
        return None, None, {"result": RES_CODE_FAILURE, "message": f"Error processing request: {str(e)}"}


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=10000)
