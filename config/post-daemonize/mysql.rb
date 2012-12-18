config = DaemonKit::Config.load("mysql.yml")
ActiveRecord::Base.establish_connection(config)
