import os


def post_fork(server, worker):
    master_pid = os.getppid()
    worker_pid = os.getpid()
    worker.log.info(f"---- worker spawned with PID of {worker_pid} by master process {master_pid}")


bind = "127.0.0.1:8000"
backlog = 2048
workers = 4
worker_class = 'gevent'  # sync, gevent, eventlet, see docs.
timeout = 30
graceful_timeout = 30

accesslog = '-'  # to stdout
errorlog = '-'  # to stdout/err
loglevel = 'info'  # debug info warning error critical
capture_output = False  # do not forward logs from stdout / err to log files.

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
