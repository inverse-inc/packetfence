import os
import time

worker_pid = os.getpid()

import redis_client
import redis

done = False


def primary_worker_register():
    while True:
        if done is True:
            break

        key = f"{redis_client.namespace}:primary_worker"

        try:
            res = redis_client.r.set(name=key, value=worker_pid, nx=True, ex=5, get=True)
            if res is None:
                print(f"primary worker is registered on PID: {worker_pid}.")
            if str(worker_pid) == res:
                redis_client.r.expire(name=key, time=10, xx=True, gt=True)

        except redis.ConnectionError:
            print("failed while trying to register primary worker: redis connection error.")
        except Exception as e:
            print(f"failed while trying to register primary worker: {str(e)}")

        time.sleep(2)
