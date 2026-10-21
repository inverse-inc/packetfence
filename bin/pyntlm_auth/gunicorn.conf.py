import os
import signal
import sys
from threading import Thread

import config_loader
import global_vars
import redis_client
import t_async_job
import t_health_checker
import t_sdnotify
import t_worker_register
import log

import logging
from gunicorn import glogging


class HealthCheckFilter(logging.Filter):
    def filter(self, record):
        return 'GET /ping' not in record.getMessage()


class CustomGunicornLogger(glogging.Logger):
    def setup(self, cfg):
        super().setup(cfg)

        logger = logging.getLogger("gunicorn.access")
        logger.addFilter(HealthCheckFilter())


NAME = "NTLM Auth API"

try:
    LISTEN = os.getenv("LISTEN")
    bind_port = int(LISTEN)
except ValueError:
    log.critical(f"invalid value for environment variable 'LISTEN', {NAME} terminated.")
    sys.exit(1)
except Exception as e:
    log.critical(f"failed to extract parameter 'LISTEN' from environment variable: {str(e)}. {NAME} terminated.")
    sys.exit(1)

config_loader.config_load()
worker_num = global_vars.c_additional_machine_accounts + 1

wsgi_app = 'entrypoint:app'

bind = f"0.0.0.0:{bind_port}"
backlog = 2048
workers = worker_num
worker_class = 'sync'
timeout = 30
graceful_timeout = 10

accesslog = '-'
errorlog = '-'
loglevel = 'debug'
logger_class = CustomGunicornLogger
capture_output = False
access_log_format = '%(h)s %(l)s %(u)s %(p)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s"'

keepalive = 2
max_requests = 10000
max_requests_jitter = 50

daemon = False

limit_request_line = 4094
limit_request_fields = 100
limit_request_field_size = 8190

reload = False


def on_starting(server):
    server.log.info("master process starting, machine account binding cleanup started.")
    if not redis_client.init_connection():
        server.log.error("unable to initialize redis connection, terminated.")
        server.stop()

    server.log.info("cleaning up machine account binding.")
    config_loader.cleanup_machine_account_binding(True)
    server.log.info("machine account binding clean up done.")

    if "gunicorn.error" in logging.Logger.manager.loggerDict:
        log.default_logger = logging.getLogger("gunicorn.error")
        log.info("default logger set to 'gunicorn.error'.")


def on_exit(server):
    server.log.info(f"master process on-exit clean up started...")
    server.log.info(f"master process on-exit clean up done...")


def worker_exit(server, worker):
    worker.log.info(f"worker process pre-exit clean up started, sending thread stop event...")

    t_async_job.stop_event.set()
    t_health_checker.stop_event.set()
    t_worker_register.stop_event.set()
    t_sdnotify.stop_event.set()


def post_fork(server, worker):
    worker.log.info(f"post fork hook: worker spawned with PID of {worker.pid} by master {server.pid}")
    global_vars.s_worker = worker

    if not redis_client.init_connection():
        worker.log.error("unable to initialize redis connection, worker failed to start")
        os.kill(server.pid, signal.SIGTERM)

    background_jobs = (
        Thread(target=t_worker_register.primary_worker_register, daemon=True, args=(worker,)),
        Thread(target=t_sdnotify.sd_notify, daemon=True, args=(worker,)),
        Thread(target=t_worker_register.gc_expire_redis_locks, daemon=True, args=(worker,))
    )

    for job in background_jobs:
        job.start()
