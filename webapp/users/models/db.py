import pymysql
pymysql.install_as_MySQLdb()  # <- esto hace que 'MySQLdb' apunte a PyMySQL

from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()
