import os
import redis

import global_vars
import log

r = None
namespace = f"ntlm-auth:{os.getenv('IDENTIFIER')}"


def init_connection():
    global r
    r = redis.StrictRedis(
        host=global_vars.c_cache_host,
        port=global_vars.c_cache_port,
        db=0,
        decode_responses=True,
        socket_timeout=5,
        retry_on_timeout=True
    )

    try:
        r.ping()
        return True
    except Exception as e:
        log.warning(f"unable to establish redis connection: {str(e)}")

    return False
