import logging
import os
import time

import request
from flask import Flask
from flaskext.mysql import MySQL

import config_loader
import global_vars
import handlers

app = Flask(__name__)

time.sleep(1)
worker_pid = os.getpid()
master_pid = os.getppid()

config_loader.cleanup_machine_account_binding()

while True:
    m = config_loader.bind_machine_account(worker_pid)
    if m is not None:
        break

    print(f"---- worker {worker_pid} failed to bind machine account: no available accounts, retrying.")
    time.sleep(1)

print(f"---- worker {worker_pid} successfully registered with machine account '{m}', ready to handle requests.")

werkzeug_logger = logging.getLogger('werkzeug')


@app.before_request
def register_logger():
    if request.path.startswith("/ping"):
        werkzeug_logger.setLevel(logging.CRITICAL)
    else:
        werkzeug_logger.setLevel(logging.INFO)


for i in range(1):
    if not global_vars.c_nt_key_cache_enabled:
        break

    c_db_port, err = config_loader.get_int_value(global_vars.c_db_port)
    if err is not None:
        global_vars.c_nt_key_cache_enabled = False
        break

    app.config['MYSQL_DATABASE_HOST'] = global_vars.c_db_host
    app.config['MYSQL_DATABASE_PORT'] = int(global_vars.c_db_port)
    app.config['MYSQL_DATABASE_USER'] = global_vars.c_db_user
    app.config['MYSQL_DATABASE_PASSWORD'] = global_vars.c_db_pass
    app.config['MYSQL_DATABASE_DB'] = global_vars.c_db
    app.config['MYSQL_DATABASE_CHARSET'] = 'utf8mb4'
    app.config['MYSQL_DATABASE_SOCKET'] = global_vars.c_db_unix_socket

    mysql = MySQL(autocommit=True, cursorclass=pymysql.cursors.DictCursor)
    mysql.init_app(app)


    @app.before_request
    def before_request():
        try:
            g.db = mysql.get_db().cursor()
        except Exception as e:
            e_code = e.args[0]
            e_msg = str(e)
            print(f"  error while init database: {e_code}, {e_msg}. Started without NT Key cache capability.")


    @app.teardown_request
    def teardown_request(exception=None):
        if hasattr(g, 'db'):
            g.db.close()

app.route('/ntlm/auth', methods=['POST'])(handlers.ntlm_auth_handler)
app.route('/ntlm/expire', methods=['POST'])(handlers.ntlm_expire_handler)
app.route('/event/report', methods=['POST'])(handlers.event_report_handler)
app.route('/ntlm/connect', methods=['GET'])(handlers.ntlm_connect_handler)
app.route('/ntlm/connect', methods=['POST'])(handlers.test_password_handler)
app.route('/ping', methods=['GET'])(handlers.ping_handler)

if __name__ == '__main__':
    app.run()
