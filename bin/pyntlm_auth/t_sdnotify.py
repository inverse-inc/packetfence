import time
from threading import Event

import sdnotify

stop_event = Event()


def sd_notify(worker):
    n = sdnotify.SystemdNotifier()
    n.notify("READY=1")

    count = 0
    while not stop_event.is_set():

        if count % 30 == 0:
            message = "WATCHDOG=1"
            n.notify(message)

            message = "STATUS=Count is {}".format(count)
            n.notify(message)

            count = 0

        count += 1
        time.sleep(1)
