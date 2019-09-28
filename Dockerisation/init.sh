#!/bin/bash
INSTALL_DIRECTORY=$(pwd)

                                                                            	
database_username=$DATABASE_USERNAME                                                                             	
database_password=$DATABASE_PASSWORD
database_port=$DATABASE_PORT
database_host=$DATABASE_HOST
database_name=$DATABASE_NAME
resetdb=$RESTOREDB


export APPSRV_HOME=opt/wildfly-14.0.1.Final
export SIGNSERVER_NODEID=node1


database_url="jdbc:mysql:\/\/${database_host}:${database_port}\/${database_name}"

wildfly_exec() {
  wildfly/bin/jboss-cli.sh --connect "$1"
}

mariadb_restore(){
		export MYSQL_PWD=${database_password}
		sleep 4
		mysql -u ${database_username} --host=${database_host} --port=${database_port} < mysql.backup
	
}

if [ ! -f init ]; then
	echo "Changing Database Settings on WildFly"
	sed -i 's/<user-name>signserver/<user-name>'$database_username'/g' wildfly/standalone/configuration/standalone.xml
    sed -i 's/<password>signserver/<password>'$database_password'/g' wildfly/standalone/configuration/standalone.xml
    sed -i 's/<connection-url>jdbc:mysql:\/\/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:9999\/signserver/<connection-url>'$database_url'/g' wildfly/standalone/configuration/standalone.xml
	
	if [ "$resetdb" = "true" ]; then
		echo "Restoring Database"
		mariadb_restore
	fi
	./wildfly/bin/standalone.sh > /tmp/server-log.txt &
	sleep 1
	while ! grep -m1 '(WildFly Core 6.0.2.Final) started in' < /tmp/server-log.txt; do
				sleep 1
				echo "Waiting for WildFly to start"
	done

	touch init
	
	tail -f /dev/null


else
	echo "Starting Wildfly"

	./wildfly/bin/standalone.sh > /tmp/server-log.txt &
	sleep 1
	while ! grep -m1 '(WildFly Core 6.0.2.Final) started in' < /tmp/server-log.txt; do
				sleep 1
				echo "Waiting for WildFly to start"
	done

	echo "WildFly Started"

	tail -f /dev/null
fi
