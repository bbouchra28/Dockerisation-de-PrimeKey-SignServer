#!/bin/bash



usage(){
        echo "Usage: ./signserver_install.sh database_host database_port  database_name database_user database_password"
	exit 1
}



[[ $# -ne 5 ]] && usage


INSTALL_DIRECTORY=$(pwd)
export APPSRV_HOME=$INSTALL_DIRECTORY/wildfly-14.0.1.Final
export SIGNSERVER_NODEID=node1


database_host=$1
database_port=$2
database_name=$3
database_username=$4
database_password=$4


WILDFLY_VERSION="14.0.1.Final"
WILDFLY_TAR="wildfly-${WILDFLY_VERSION}.tar.gz"
WILDFLY_TAR_SHA256=e12092ec6a6e048bf696d5a23c3674928b41ddc3f810016ef3e7354ad79fc746
WILDFLY_DIR="wildfly-${WILDFLY_VERSION}"
WILDFLY_DOWNLOAD_URL=https://download.jboss.org/wildfly/${WILDFLY_VERSION}/${WILDFLY_TAR}


MARIADB_CONNECTOR_VERSION="2.1.0"
MARIADB_DOWNLOAD_URL="https://downloads.mariadb.com/Connectors/java/connector-java-2.1.0/mariadb-java-client-2.1.0.jar"
MARIADB_DOWNLOAD_SHA256="562b8d4ab93de9b67baa7bed223741e8a7fed3d239bbb9eb377338d85dce8578"

XALAN_VERSION="2.7.2"
XALAN_DOWNLOAD_URL="https://repo1.maven.org/maven2/xalan/xalan/2.7.2/xalan-2.7.2.jar"
XALAN_DOWNLOAD_SHA256="a44bd80e82cb0f4cfac0dac8575746223802514e3cec9dc75235bc0de646af14"

SERIALIZER_VERSION="2.7.2"
SERIALIZER_DOWNLOAD_URL="https://repo1.maven.org/maven2/xalan/serializer/2.7.2/serializer-2.7.2.jar"
SERIALIZER_DOWNLOAD_SHA256="e8f5b4340d3b12a0cfa44ac2db4be4e0639e479ae847df04c4ed8b521734bb4a"

SIGNSERVER_VERSION="5.0.0.Final"
SIGNSERVER_DOWNLOAD_URL="https://downloads.sourceforge.net/project/signserver/signserver/5.0/signserver-ce-5.0.0.Final-bin.zip?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fsignserver%2Ffiles%2Fsignserver%2F5.0%2Fsignserver-ce-5.0.0.Final-bin.zip%2Fdownload&ts=1569613365" 
SIGNSERVER_TAR="signserver-ce-${SIGNSERVER_VERSION}.zip"
SIGNSERVER_TAR_SHA256=99d27fdccc47ee6851cd2c7aa77af7334f3473e5069bc9b4a5c01e0254da45aa
SIGNSERVER_DIR="signserver-ce-${SIGNSERVER_VERSION}"




init_mariadb() {

	cd $INSTALL_DIRECTORY ||exit 1
	cat signserver/doc/sql-scripts/drop-tables-signserver-mysql.sql | mysql --host=${database_host} --protocol=tcp --port=${database_port} --user=${database_username} --database=${database_name} --password=${database_password}

}

create_mariadb_index() {

  cd $INSTALL_DIRECTORY || exit 1
  cat signserver/doc/sql-scripts/create-tables-signserver-mysql.sql | mysql --host=${database_host} --protocol=tcp --port=3306 --user=${database_username} --database=${database_name} --password=${database_password}
  cat signserver/doc/sql-scripts/create-index-signserver.sql | mysql --host=${database_host} --protocol=tcp --port=3306 --user=${database_username} --database=${database_name} --password=${database_password}

}

backup_mariadb(){

	 export MYSQL_PWD=${database_password}
	 mysqldump -h ${database_host} --databases ${database_name} --user ${database_username} --port ${database_port} > mysql.backup

}

wildfly_killall() {
  pidof java > /dev/null 2> /dev/null
  if [ $? -eq 0 ]; then
    killall -9 java
    sleep 10
  fi
}

wildfly_exec() {
  wildfly/bin/jboss-cli.sh --connect "$1"
}

wildfly_shutdown() {
  cd $INSTALL_DIRECTORY || exit 1
  wildfly/bin/jboss-cli.sh --connect command=:shutdown
}

wildfly_reload() {
  cd $INSTALL_DIRECTORY || exit 1
  wildfly/bin/jboss-cli.sh --connect command=:reload
}

wildfly_check() {
  DURATION_SECONDS=30
  if [ ! -z "$1" ]; then
    DURATION_SECONDS="$1"
  fi
  DURATION=$(echo "$DURATION_SECONDS / 5" | bc)

  echo "wait ${DURATION_SECONDS}s for start up wildfly"
  cd $INSTALL_DIRECTORY || exit 1
  for i in `seq 1 $DURATION`; do
    wildfly/bin/jboss-cli.sh --connect ":read-attribute(name=server-state)" | grep "result" | awk '{ print $3; }'|grep running
    if [ $? -eq 0 ]; then
      return 0
    fi
    sleep 5
  done
  echo "wildfly not started after ${DURATION_SECONDS}s, exit"
  exit 1
}

wildfly_keystore(){

        mkdir $INSTALL_DIRECTORY/$WILDFLY_DIR/standalone/configuration/keystore/
        cp $INSTALL_DIRECTORY/signserver-ce-5.0.0.Final/res/test/dss10/dss10_demo-tls.jks $INSTALL_DIRECTORY/$WILDFLY_DIR/standalone/configuration/keystore/keystore.jks
        cp $INSTALL_DIRECTORY/signserver-ce-5.0.0.Final/res/test/dss10/dss10_truststore.jks $INSTALL_DIRECTORY/$WILDFLY_DIR/standalone/configuration/keystore/truststore.jks

}

wildfly_enable_ajp() {
  wildfly/bin/jboss-cli.sh --connect "/subsystem=undertow/server=default-server/ajp-listener=ajp-listener:add(socket-binding=ajp, scheme=https, enabled=true)"
}

download(){

  if [ ! -d Download ]; then
    mkdir Download
  fi

  echo									
  echo "Downloading(if needed) and unpacking WildFly"
  if [ ! -f Download/${WILDFLY_TAR} ]; then
    cd Download
    echo "Downloading WildFly to $(pwd)"
    curl -o ${WILDFLY_TAR} -L ${WILDFLY_DOWNLOAD_URL}
    echo ${WILDFLY_TAR_SHA256} ${WILDFLY_TAR} > ${WILDFLY_TAR}.sha256
    sha256sum --check ${WILDFLY_TAR}.sha256
    if [ $? -ne 0 ]; then
       echo "SHA256 for wildfly does not match"
       rm ${WILDFLY_TAR}
       exit 1
    fi
    cd ..
  fi

  if [ ! -f Download/mariadb-java-client-${MARIADB_CONNECTOR_VERSION}.jar ]; then
    cd Download
    echo "Downloading mariadb Java Connector to $(pwd)"
    curl -o mariadb-java-client-${MARIADB_CONNECTOR_VERSION}.jar -L ${MARIADB_DOWNLOAD_URL}
    echo ${MARIADB_DOWNLOAD_SHA256} mariadb-java-client-${MARIADB_CONNECTOR_VERSION}.jar > mariadb-java-client-${MARIADB_CONNECTOR_VERSION}.jar.sha256
    sha256sum --check mariadb-java-client-${MARIADB_CONNECTOR_VERSION}.jar.sha256
    if [ $? -ne 0 ]; then
       echo "SHA256 for mariadb does not match"
       rm mariadb-java-client-${MARIADB_CONNECTOR_VERSION}.jar
       exit 1
    fi
    cd ..
  fi

  if [ ! -f Download/xalan-${XALAN_VERSION}.jar ]; then
    cd Download
    echo "Downloading xalan to $(pwd)"
    curl -o xalan-${XALAN_VERSION}.jar -L ${XALAN_DOWNLOAD_URL}
    echo ${XALAN_DOWNLOAD_SHA256} xalan-${XALAN_VERSION}.jar > xalan-${XALAN_VERSION}.jar.sha256
    sha256sum --check xalan-${XALAN_VERSION}.jar.sha256
    if [ $? -ne 0 ]; then
       echo "SHA256 for XALAN does not match"
       rm xalan-${XALAN_VERSION}.jar
       exit 1
    fi
    cd ..
  fi

  if [ ! -f Download/serializer-${SERIALIZER_VERSION}.jar ]; then
    cd Download
    echo "Downloading seriliazer to $(pwd)"
    curl -o serializer-${SERIALIZER_VERSION}.jar -L ${SERIALIZER_DOWNLOAD_URL}
    echo ${SERIALIZER_DOWNLOAD_SHA256} serializer-${SERIALIZER_VERSION}.jar > serializer-${SERIALIZER_VERSION}.jar.sha256
    sha256sum --check serializer-${SERIALIZER_VERSION}.jar.sha256
    if [ $? -ne 0 ]; then
       echo "SHA256 for Seriliazer does not match"
       rm serializer-${SERIALIZER_VERSION}.jar
       exit 1
    fi
    cd ..
  fi

  if [ ! -f Download/${SIGNSERVER_TAR} ]; then
    cd Download
    echo "Downloading SIGNSERVER to $(pwd)"
    curl -o ${SIGNSERVER_TAR} -L ${SIGNSERVER_DOWNLOAD_URL}
    echo ${SIGNSERVER_TAR_SHA256} ${SIGNSERVER_TAR} > ${SIGNSERVER_TAR}.sha256
    sha256sum --check ${SIGNSERVER_TAR}.sha256
    if [ $? -ne 0 ]; then
       echo "SHA256 for SignServer does not match"
       rm ${SIGNSERVER_TAR}
       exit 1
    fi
    cd ..
  fi


}

config_wildfly(){
  
  wildfly_killall

  cd $INSTALL_DIRECTORY/wildfly/bin || exit 1
  sed -i.bak 's/JAVA_OPTS="-Xms64m -Xmx512m -XX:MaxPermSize=256m -Djava.net.preferIPv4Stack=true"/JAVA_OPTS="-Xms2048m -Xmx2048m -XX:MaxPermSize=384m -Djava.net.preferIPv4Stack=true"/g' standalone.conf
  cd $INSTALL_DIRECTORY

  nohup wildfly/bin/standalone.sh -b 0.0.0.0 > /dev/null 2> /dev/null &
  sleep 3
  wildfly_check || exit 1
  wildfly_enable_ajp || exit 1
  wildfly_reload || exit 1
  wildfly_check || exit 1
  wildfly_keystore
  
  echo "remove any existing TLS and HTTP configuration and allow configuring port 8443"

  wildfly_exec "/subsystem=undertow/server=default-server/http-listener=default:remove"
  wildfly_exec "/subsystem=undertow/server=default-server/https-listener=https:remove"
  wildfly_exec "/socket-binding-group=standard-sockets/socket-binding=http:remove"
  wildfly_exec "/socket-binding-group=standard-sockets/socket-binding=https:remove"
  wildfly_exec ":reload"

  echo "Configure interfaces using the appropriate bind address. This example uses 0.0.0.0 to make it available for anyone"

  wildfly_exec '/interface=http:add(inet-address="0.0.0.0")'
  wildfly_exec '/interface=httpspub:add(inet-address="0.0.0.0")'
  wildfly_exec '/interface=httpspriv:add(inet-address="0.0.0.0")'

  echo "Configure the HTTPS httpspriv listener and set up the private port requiring the client certificate. "
  wildfly_exec '/core-service=management/security-realm=SSLRealm:add()'
  wildfly_exec '/core-service=management/security-realm=SSLRealm/server-identity=ssl:add(keystore-path="keystore/keystore.jks", keystore-relative-to="jboss.server.config.dir", keystore-password="serverpwd", alias="localhost")'
  wildfly_exec ':reload'
  wildfly_exec '/core-service=management/security-realm=SSLRealm/authentication=truststore:add(keystore-path="keystore/truststore.jks", keystore-relative-to="jboss.server.config.dir", keystore-password="changeit")'
  wildfly_exec ':reload'
  wildfly_exec '/socket-binding-group=standard-sockets/socket-binding=httpspriv:add(port="8443",interface="httpspriv")'
  wildfly_exec '/subsystem=undertow/server=default-server/https-listener=httpspriv:add(socket-binding="httpspriv", security-realm="SSLRealm", verify-client=REQUIRED, max-post-size="10485760", enable-http2="false")'

  echo "Configure the default HTTP listener."
  wildfly_exec '/socket-binding-group=standard-sockets/socket-binding=http:add(port="8080",interface="http")'
  wildfly_exec '/subsystem=undertow/server=default-server/http-listener=default:add(socket-binding=http, max-post-size="10485760", enable-http2="false")'
  wildfly_exec '/subsystem=undertow/server=default-server/http-listener=default:write-attribute(name=redirect-socket, value="httpspriv")'
  wildfly_exec ':reload'
  wildfly_check
  
  echo "Configure the HTTPS httpspub listener and set up the public SSL port not requiring the client certificate."
  wildfly_exec '/socket-binding-group=standard-sockets/socket-binding=httpspub:add(port="8442",interface="httpspub")'
  wildfly_exec '/subsystem=undertow/server=default-server/https-listener=httpspub:add(socket-binding="httpspub", security-realm="SSLRealm", max-post-size="10485760", enable-http2="false")'

  echo "Configure the remoting (HTTP) listener and secure the CLI by removing the http-remoting-connector from using the HTTP port and instead use a separate port 4447."
  wildfly_exec '/subsystem=remoting/http-connector=http-remoting-connector:remove'
  wildfly_exec '/subsystem=remoting/http-connector=http-remoting-connector:add(connector-ref="remoting",security-realm="ApplicationRealm")'
  wildfly_exec '/socket-binding-group=standard-sockets/socket-binding=remoting:add(port="4447")'
  wildfly_exec '/subsystem=undertow/server=default-server/http-listener=remoting:add(socket-binding=remoting, max-post-size="10485760", enable-http2="false")'
  wildfly_check

  echo "Configure WSDL"
  wildfly_exec '/subsystem=webservices:write-attribute(name=wsdl-host, value=jbossws.undefined.host'
  wildfly_exec '/subsystem=webservices:write-attribute(name=modify-wsdl-address, value=true)'
  wildfly_exec ':reload'

  echo "Configure the URI encoding"
  wildfly_exec '/system-property=org.apache.catalina.connector.URI_ENCODING:remove()'
  wildfly_exec '/system-property=org.apache.catalina.connector.URI_ENCODING:add(value=UTF-8)'
  wildfly_exec '/system-property=org.apache.catalina.connector.USE_BODY_ENCODING_FOR_QUERY_STRING:remove()'
  wildfly_exec '/system-property=org.apache.catalina.connector.USE_BODY_ENCODING_FOR_QUERY_STRING:add(value=true)'
  wildfly_exec ':reload'

  echo " Copying XALAN and Serializer annd Mariadb JAVA connector"

  cp $INSTALL_DIRECTORY/Download/xalan-2.7.2.jar $INSTALL_DIRECTORY/Download/serializer-2.7.2.jar $INSTALL_DIRECTORY/${WILDFLY_DIR}/modules/system/layers/base/org/apache/xalan/main/
  sed -i 's/path="serializer-2.7.1.jbossorg-4.jar"/path="serializer-2.7.2.jar"/g' $INSTALL_DIRECTORY/${WILDFLY_DIR}/modules/system/layers/base/org/apache/xalan/main/module.xml
  sed -i 's/path="xalan-2.7.1.jbossorg-4.jar"/path="xalan-2.7.2.jar"/g' $INSTALL_DIRECTORY/${WILDFLY_DIR}/modules/system/layers/base/org/apache/xalan/main/module.xml



  echo "Adding data source now"
  cp  $INSTALL_DIRECTORY/Download/mariadb-java-client-2.1.0.jar $INSTALL_DIRECTORY/${WILDFLY_DIR}/standalone/deployments/mariadb-java-client.jar
  wildfly_exec "data-source add --name=signserverds --driver-name=\"mariadb-java-client.jar\" --connection-url=\"jdbc:mysql://${database_host}:${database_port}/signserver\" --jndi-name=\"java:/SignServerDS\" --use-ccm=true --driver-class=\"org.mariadb.jdbc.Driver\" --user-name=\"signserver\" --password=\"signserver\" --validate-on-match=true --background-validation=false --prepared-statements-cache-size=50 --share-prepared-statements=true --min-pool-size=5 --max-pool-size=150 --pool-prefill=true --transaction-isolation=TRANSACTION_READ_COMMITTED --check-valid-connection-sql=\"select 1;\" --enabled=true"
  wildfly_exec ':reload'

}

deploy_signserver(){

  cp $INSTALL_DIRECTORY/signserver-ce-5.0.0.Final/conf/signserver_deploy.properties.sample $INSTALL_DIRECTORY/signserver-ce-5.0.0.Final/conf/signserver_deploy.properties

  $INSTALL_DIRECTORY/signserver-ce-5.0.0.Final/bin/ant deploy



}

rm -rf "${WILDFLY_DIR}" > /dev/null 2> /dev/null

echo "Downloading Wildfly, MariaDB Driver, Xalan, Serializer and SignServer"
echo
echo
download

echo "Extracting"
echo
echo

tar xvf Download/${WILDFLY_TAR}
if [ -h wildfly ]; then
  rm -f wildfly
fi										
ln -s "${WILDFLY_DIR}" wildfly

unzip Download/${SIGNSERVER_TAR}
if [ -h signserver-ce ]; then
  rm -f signserver-ce
fi
										
ln -s "${SIGNSERVER_DIR}" signserver

echo "Droping Database"
echo
echo
init_mariadb

echo "Preparing Database"
echo
echo
create_mariadb_index

echo "Deploying Keystore"
echo
echo
wildfly_keystore

echo "Wildfly Configuration"
echo
echo
config_wildfly

echo "Deploying SignServer CE"
echo
echo
deploy_signserver

echo "Backing up database"
echo
echo 

backup_mariadb

