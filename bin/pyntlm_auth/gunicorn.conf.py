import os
import sys

NAME = "NTLM Auth API"

try:
    LISTEN = os.getenv("LISTEN")
    bind_port = int(LISTEN)
except ValueError:
    print(f"invalid value for environment variable 'LISTEN', {NAME} terminated.")
    sys.exit(1)
except Exception as e:
    print(f"failed to extract parameter 'LISTEN' from environment variable: {str(e)}. {NAME} terminated.")
    sys.exit(1)

try:
    WORKERS = os.getenv("WORKERS")
    worker_num = int(WORKERS)
except ValueError:
    print(f"invalid value for 'WORKERS'. WORKERS is set to 1.")
    worker_num = 1
except Exception as e:
    print(f"failed to extract parameter 'WORKERS' from environment variables: {str(e)}. WORKERS is set to 1.")
    worker_num = 1

wsgi_app = 'entrypoint:app'

bind = f"127.0.0.1:{bind_port}"
backlog = 2048
workers = worker_num
worker_class = 'sync'  # use sync, do not use 'gevent', or 'eventlet' due to block operations.
timeout = 30
graceful_timeout = 30

accesslog = '-'  # to stdout
errorlog = '-'  # to stdout/err
loglevel = 'info'  # debug info warning error critical
capture_output = False  # do not forward logs from stdout / err to log files.
# access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s"'     # default access log format.
access_log_format = '%(h)s %(l)s %(u)s %(p)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s"'

keepalive = 2
max_requests = 100000
max_requests_jitter = 50

daemon = False
# pidfile = '/tmp/gunicorn.pid'

limit_request_line = 4094
limit_request_fields = 100
limit_request_field_size = 8190

# preload_app = True
reload = True  # reload apps when the source code changes, For debugging purpose only.


def post_fork(server, worker):
    master_pid = os.getppid()
    worker_pid = os.getpid()
    worker.log.info(f"---- worker spawned with PID of {worker_pid} by master process {master_pid}")

# SETNX
