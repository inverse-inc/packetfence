import datetime
import time
from threading import Event

import redis

import global_vars
import redis_client
import rpc

stop_event = Event()


def async_auth(worker):
    key = f"{redis_client.namespace}:async-auth:{worker.pid}"

    while not stop_event.is_set():
        try:
            res = redis_client.r.lpop(name=key)
            if res is None:
                time.sleep(0.5)
            else:
                worker.log.info(f"Data is: {res}")

        except redis.ConnectionError:
            worker.log.warning(f"failed fetching async auth job: key = '{key}': redis connectivity issue.")
            time.sleep(1)
        except Exception as e:
            worker.log.warning(f"failed fetching async auth job: key = '{key}': error = {str(e)}")
            time.sleep(1)
    worker.log.info("Thread 'async_auth' is done.")


def async_test(worker):
    bind_account = global_vars.s_bind_account
    key = f"{redis_client.namespace}:async-test:jobs:{bind_account}"

    while not stop_event.is_set():
        try:
            res = redis_client.r.rpop(name=key)
            if res is None:
                time.sleep(0.5)
            else:
                s = res.split(":")
                job_time = s[0]
                password = ""
                if len(s) == 2:
                    password = s[1]

                try:
                    job_time_f = float(job_time)
                    if job_time_f + 2 < time.time():
                        job_time_fmt = datetime.datetime.fromtimestamp(job_time_f).strftime("%Y-%m-%d %H:%M:%S.%f")
                        worker.log.warning(f"deprecated job submitted at {job_time_fmt}, dropped. payload: {res}")
                    else:
                        worker.log.info(f"deal machine account test for: {bind_account} with password '{password}'")
                        _test_schannel(job_time, bind_account, password)
                except Exception as e:
                    worker.log.warning(f"can not convert job_id '{job_time}' to float number: {str(e)}, payload: {res}")

        except redis.ConnectionError:
            worker.log.warning(f"failed fetching async test job: key = '{key}': redis connectivity issue.")
            time.sleep(1)
        except Exception as e:
            worker.log.warning(f"failed fetching async test job: key = '{key}': error = {str(e)}")
            time.sleep(1)
    worker.log.info("Thread 'async_test' is done.")


def _test_schannel(job_id, machine_account, password=""):

    key_lock = f"{redis_client.namespace}:async-test:lock:{job_id}"
    try:
        v = redis_client.r.brpop(key_lock, 2)
        if v is None:
            msg = f"lock '{key_lock}' wait timed out. job '{job_id}' failed."
            global_vars.s_worker.log.warning(msg)
            return

    except redis.ConnectionError:
        msg = f"redis connection error occurred when obtaining lock '{key_lock}', job '{job_id}' failed."
        global_vars.s_worker.log.warning(msg)
        return
    except Exception as e:
        msg = f"error occurred when obtaining lock '{key_lock}': {str(e)}, job '{job_id}' failed."
        global_vars.s_worker.log.warning(msg)
        return

    if not password:
        password = global_vars.s_password_ro

    with global_vars.s_lock:
        global_vars.s_reconnect_id = global_vars.s_connection_id
        global_vars.c_password = password

    (
        global_vars.s_secure_channel_connection,
        global_vars.s_machine_cred,
        global_vars.s_connection_id,
        error_code, error_message
    ) = rpc.get_secure_channel_connection()

    with global_vars.s_lock:
        global_vars.c_password = global_vars.s_password_ro

    try:
        redis_client.r.lpush(key_lock, global_vars.s_worker.pid)
    except redis.ConnectionError:
        msg = f"redis connection error occurred when releasing lock '{key_lock}', job '{job_id}' failed."
        global_vars.s_worker.log.warning(msg)
        return
    except Exception as e:
        msg = f"error occurred when releasing lock '{key_lock}': {str(e)}, job '{job_id}' failed."
        global_vars.s_worker.log.warning(msg)
        return

    if error_code == 0:
        result = "OK"
    else:
        result = f"error code: {error_code}, error message: {error_message}"
        # typically, we'll get an NT_STATUS_ACCESS_DENIED error is password is wrong.

    key = f"{redis_client.namespace}:async-test:results:{job_id}:{machine_account}"

    try:
        redis_client.r.set(name=key, value=result, ex=5)
    except redis.ConnectionError:
        msg = f"redis connection error occurred when writing async test job (id = '{job_id}') results: {result}"
        global_vars.s_worker.log.warning(msg)
    except Exception as e:
        msg = f"error '{str(e)}' occurred when writing async test job (id = '{job_id}') results: {result}"
        global_vars.s_worker.log.warning(msg)
