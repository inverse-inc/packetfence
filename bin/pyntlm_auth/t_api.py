import pymysql
from flask import Flask, g
from flaskext.mysql import MySQL

import config_loader
import global_vars
import handlers


def api():
    config_loader.config_load()

    app = Flask(__name__)

    app.config['MYSQL_DATABASE_HOST'] = global_vars.c_db_host
    app.config['MYSQL_DATABASE_PORT'] = int(global_vars.c_db_port)
    app.config['MYSQL_DATABASE_USER'] = global_vars.c_db_user
    app.config['MYSQL_DATABASE_PASSWORD'] = global_vars.c_db_pass
    app.config['MYSQL_DATABASE_DB'] = global_vars.c_db
    app.config['MYSQL_DATABASE_CHARSET'] = 'utf8mb4'

    mysql = MySQL(autocommit=True, cursorclass=pymysql.cursors.DictCursor)
    mysql.init_app(app)

    @app.before_request
    def before_request():
        g.db = mysql.get_db().cursor()

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
