import logging
import pymysql
from flask import Flask, g, request
from flaskext.mysql import MySQL

import config_loader
import global_vars
import handlers


def api():
    config_loader.config_load()

    app = Flask(__name__)

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

    app.run(threaded=True, host='0.0.0.0', port=int(global_vars.c_listen_port))
