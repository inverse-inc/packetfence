import time
from threading import Event

stop_event = Event()


# we'll do health check and schannel keep alive here.
def health_check(worker):
    while not stop_event.is_set():
        # print(f"health check on {worker.pid}")
        time.sleep(30)
