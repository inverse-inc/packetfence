import redis

import global_vars

r = None
namespace = "ntlm-auth"


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
        print(f"unable to establish redis connection: {str(e)}")

    return False
