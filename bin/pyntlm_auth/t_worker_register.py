import time
from threading import Event

import redis

import redis_client

stop_event = Event()


def primary_worker_register(worker):
    key = f"{redis_client.namespace}:primary_worker"
    while not stop_event.is_set():
        try:
            res = redis_client.r.set(name=key, value=worker.pid, nx=True, ex=5, get=True)
            if res is None:
                worker.log.info(f"primary worker is registered on PID: {worker.pid}.")
            if str(worker.pid) == res:
                redis_client.r.expire(name=key, time=10, xx=True, gt=True)

        except redis.ConnectionError:
            worker.log.warning("failed registering primary worker: redis connection error.")
        except Exception as e:
            worker.log.warning(f"failed registering primary worker: {str(e)}")

        time.sleep(2)
