import time
from threading import Event

import redis

import redis_client

stop_event = Event()
is_me = Event()


def primary_worker_register(worker):
    key = f"{redis_client.namespace}:primary_worker"
    while not stop_event.is_set():
        try:
            res = redis_client.r.set(name=key, value=worker.pid, nx=True, ex=5, get=True)
            if res is None:
                worker.log.info(f"primary worker is registered on PID: {worker.pid}.")
                is_me.set()
            if str(worker.pid) == res:
                redis_client.r.expire(name=key, time=10, xx=True, gt=True)

        except redis.ConnectionError:
            worker.log.warning("failed registering primary worker: redis connection error.")
        except Exception as e:
            worker.log.warning(f"failed registering primary worker: {str(e)}")

        time.sleep(2)


def gc_expire_redis_locks(worker):
    while not stop_event.is_set():
        if is_me.is_set():
            try:
                keys_iter = redis_client.r.scan_iter(match=f"{redis_client.namespace}:async-test:lock:*", count=10)
                for key in keys_iter:
                    parts = key.split(":")
                    if len(parts) == 4:
                        try:
                            job_time_f = float(parts[3])
                            if time.time() - job_time_f > 60:
                                redis_client.r.delete(key)
                        except Exception as e:
                            msg = f"error '{str(e)}' occurred when trying to remove expired lock key: '{key}'"
                            worker.log.warning(msg)
            except redis.ConnectionError:
                worker.log.warning(f"can not scanning expired redis lock keys, redis connection error.")
            except Exception as e:
                worker.log.warning(f"can not scanning expired redis lock keys: {str(e)}.")

        time.sleep(10)
