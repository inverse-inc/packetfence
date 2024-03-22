import time

import sdnotify


def sd_notify():
    n = sdnotify.SystemdNotifier()
    n.notify("READY=1")
    count = 1
    while True:
        # print("Running... {}".format(count))
        n.notify("STATUS=Count is {}".format(count))
        count += 1
        time.sleep(30)
