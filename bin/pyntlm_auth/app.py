from threading import Thread

import t_api
import t_sdnotify

if __name__ == '__main__':
    t1 = Thread(target=t_api.api)
    t2 = Thread(target=t_sdnotify.sd_notify)
    t1.start()
    t2.start()
    t1.join()
    t2.join()
