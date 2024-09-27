import os
import time
from threading import Thread

from flask import Flask

import config_loader
import t_sdnotify
import t_worker_register

app = Flask(__name__)

time.sleep(1)
worker_pid = os.getpid()
master_pid = os.getppid()


def signal_handler(sig, frame):
    t_worker_register.done = True
    t_sdnotify.done = True
    for job in background_jobs:
        job.join()


# Do not register signal handler and we'll have a quicker worker start / stop.
# signal.signal(signal.SIGINT, signal_handler)
# signal.signal(signal.SIGTERM, signal_handler)

background_jobs = (
    Thread(target=t_worker_register.primary_worker_register, daemon=True),
    Thread(target=t_sdnotify.sd_notify, daemon=True)
)

for job in background_jobs:
    job.start()

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
