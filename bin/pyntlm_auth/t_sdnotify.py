import time

import sdnotify

done = False


def sd_notify(worker):
    n = sdnotify.SystemdNotifier()
    n.notify("READY=1")

    count = 0
    while True:
        if done is True:
            break

        if count % 30 == 0:
            message = "WATCHDOG=1"
            n.notify(message)
            print(f"==== sdnotify message is: {message}")

            message = "STATUS=Count is {}".format(count)
            n.notify(message)
            print(f"==== sdnotify message is: {message}")

            count = 0

        count += 1
        time.sleep(1)
