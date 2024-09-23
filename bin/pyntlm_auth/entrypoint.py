import os
import time

from flask import Flask

app = Flask(__name__)

time.sleep(1)

worker_pid = os.getpid()
master_pid = os.getppid()
print(f"----Flask is now ready to handle HTTP requests, worker PID = {worker_pid}")



@app.route('/')
def index():
    return f"Hello, this is a Flask app running with Gunicorn! (handled by pid {worker_pid} ......\n"


if __name__ == '__main__':
    app.run()
