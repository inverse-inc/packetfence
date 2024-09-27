import redis

r = redis.StrictRedis(
    host='100.64.0.1', port=6379, db=0,
    decode_responses=True,
    socket_timeout=5,
    retry_on_timeout=True
)

namespace = "ntlm-auth"

