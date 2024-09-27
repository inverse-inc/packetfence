import os
import time

from flask import Flask

import config_loader

app = Flask(__name__)

time.sleep(1)
worker_pid = os.getpid()
master_pid = os.getppid()

config_loader.cleanup_machine_account_binding()

while True:
    m = config_loader.bind_machine_account(worker_pid)
    if m is not None:
        break

    print(f"---- worker {worker_pid} failed to bind machine account: no available accounts, retrying.")
    time.sleep(1)

print(f"---- worker {worker_pid} successfully registered with machine account '{m}', ready to handle requests.")


@app.route('/')
def index():
    return f"Hello, this is a Flask app running with Gunicorn! (handled by pid {worker_pid} ......\n"


if __name__ == '__main__':
    app.run()
