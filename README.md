1. [ Description. ](#desc)


<a name="desc"></a>
## Introduction

## Prépartion

Prérequis dont on doit disposer avant de réaliser l'installation de PrimeKey SignServer CE:

- Une machine virtuelle CentOS/Debian.
- Docker
- Docker-compose
- Wildfly 14.0.1.Final
- OpenJDK 8 ou Oracle Java 8
- Apache Ant
- Base de données MariaDB
- SignServer CE 5.0.0.Final
- Répertoire SignServer dans /opt


## Partie I : Installation Manuelle

### Installation de Java et Apache Ant

Pour installer Java sur CentOS il suffit d'exécuter la commande suivante:

`sudo yum install java-1.8.0-openjdk`

Ensuite, on installe Apache Ant :

`sudo yum install ant`

### Installation et préparation de la base de données MariaDB

Tout d'abord on commence par installer la base de données Mariadb :

`sudo yum install mariadb mariadb-server`

Ensuite on vérifie si la base de données est démarrée:

`systemctl status mariadb`

On se connecte sur MariaDB: 

`mysql -u root`

Puis on crée la base de données signserver et on ajoute l'utilisateur signserver@localhost:

`CREATE DATABASE signserver;`

`GRANT ALL PRIVILEGES ON signserver.* TO signserver@localhost IDENTIFIED BY 'signserver';`

Afin d'initialiser (création des tables nécessaires pour l'installation et le fonctionnement de SignServer) la base de données, on a besoin des scripts SQL fournit par PrimeKey.

On télécharge SignServer-ce-5.0.0.Final dans /opt/SignServer :

`curl -o /opt/SignServer/signserver-ce-5.0.0.Final-bin.zip -L https://downloads.sourceforge.net/project/signserver/signserver/5.0/signserver-ce-5.0.0.Final-bin.zip?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fsignserver%2Ffiles%2Fsignserver%2F5.0%2Fsignserver-ce-5.0.0.Final-bin.zip%2Fdownload&ts=1569520335`

Et puis on unzip le fichier :

`unzip /opt/SignServer/signserver-ce-5.0.0.Final-bin.zip`

Maintenant on exécute les deux scripts SQL qui se trouvent dans: 

`/opt/SignServer/signserver-ce-5.0.0.Final/doc/sql-scripts/create-tables-signserver-mysql.sql`

et 

`/opt/SignServer/signserver-ce-5.0.0.Final/doc/sql-scripts/create-index-signserver.sql`

### Installation et configuration de Wildfly 14

On commence par télécharger Wildfly :

`curl -o /opt/SignServer/wildfly-14.0.1.Final.zip -L https://download.jboss.org/wildfly/14.0.1.Final/wildfly-14.0.1.Final.zip`

Ensuite on unzip l'archive:

`unzip /opt/SignServer/wildfly-14.0.1.Final.zip`

`cd /opt/SignServer/wildfly-14.0.1.Final`

Et on démarre le serveur Wildfly:

`./bin/standalone.sh`

Dans ce tutorial, on utilise les paires de clés et certificats fournit par PrimeKey SignServer.

Attention! 

Si vous utiliser SignServer en Prod vous devez utiliser vos propre certificats et paires de clés !

On onfigure un HTTPS mutuel, donc on aura besoin d'un keystore et un truststore.

On crée un répertoire Keystore pour stocker le magasin de clés TLS du serveur Web:

`mkdir /opt/SignServer/wildfly-14.0.1.Final/standalone/configuration/keystore/`

On copie le keystore (certificat et paire de clés):

`cp /opt/SignServer/signserver-ce-5.0.0.Final/res/test/dss10/dss10_demo-tls.jks /opt/SignServer/wildfly-14.0.1.Final/standalone/configuration/keystore/keystore.jks`

Puis le magasin de confiance:

`cp /opt/SignServer/signserver-ce-5.0.0.Final/res/test/dss10/dss10_truststore.jks /opt/SignServer/wildfly-14.0.1.Final/standalone/configuration/keystore/truststore.jks`

#### Configuration de TLS et HTTP

On démarre la CLI JBOSS (Assurer vous que votre Wildfly est démarré):

`/opt/SignServer/wildfly-14.0.1.Final/bin/jboss-cli.sh -c`

On supprime les configurations TLS et HTTP existantes et on autorise la configuration du port 8443:

`/subsystem=undertow/server=default-server/http-listener=default:remove`

`/subsystem=undertow/server=default-server/https-listener=https:remove`

`/socket-binding-group=standard-sockets/socket-binding=http:remove`

`/socket-binding-group=standard-sockets/socket-binding=https:remove`

`:reload`

On Configure les interfaces en utilisant l'adresse de liaison appropriée, dans ce tuto on utilise 0.0.0.0 ce qui rend Wildfly disponible pour tout le monde:

`/interface=http:add(inet-address="0.0.0.0")`

`/interface=httpspub:add(inet-address="0.0.0.0")`

`/interface=httpspriv:add(inet-address="0.0.0.0")`

On configure HTTPS httpspriv le port privé nécessitant le certificat client. (On utilise les paires de clés et certificats fournit par PrimeKey pour tester SignServer, Veuillez changer les mot de passes)


`/core-service=management/security-realm=SSLRealm:add()`

`/core-service=management/security-realm=SSLRealm/server-identity=ssl:add(keystore-path="keystore/keystore.jks", keystore-relative-to="jboss.server.config.dir", keystore-password="serverpwd", alias="localhost")`

`:reload`

`/core-service=management/security-realm=SSLRealm/authentication=truststore:add(keystore-path="keystore/truststore.jks", keystore-relative-to="jboss.server.config.dir", keystore-password="changeit")`

`:reload`

`/socket-binding-group=standard-sockets/socket-binding=httpspriv:add(port="8443",interface="httpspriv")`

`/subsystem=undertow/server=default-server/https-listener=httpspriv:add(socket-binding="httpspriv", security-realm="SSLRealm", verify-client=REQUIRED, max-post-size="10485760", enable-http2="false")` 

On configure le listener HTTP par défaut:

`/socket-binding-group=standard-sockets/socket-binding=http:add(port="8080",interface="http")`

`/subsystem=undertow/server=default-server/http-listener=default:add(socket-binding=http, max-post-size="10485760", enable-http2="false")`

`/subsystem=undertow/server=default-server/http-listener=default:write-attribute(name=redirect-socket, value="httpspriv")`

`:reload`

 On Configure HTTPS httpspub et le port SSL public ne nécessitant pas le certificat client:
 
`/socket-binding-group=standard-sockets/socket-binding=httpspub:add(port="8442",interface="httpspub")`

`/subsystem=undertow/server=default-server/https-listener=httpspub:add(socket-binding="httpspub", security-realm="SSLRealm", max-post-size="10485760", enable-http2="false")`

On configure le remoting (HTTP) et on sécurise l'interface de ligne de commande en supprimant le connecteur http-remoting-using du port HTTP et utilisez plutôt un port séparé (4447) :

`/subsystem=remoting/http-connector=http-remoting-connector:remove`

`/subsystem=remoting/http-connector=http-remoting-connector:add(connector-ref="remoting",security-realm="ApplicationRealm")`

`/socket-binding-group=standard-sockets/socket-binding=remoting:add(port="4447")`

`/subsystem=undertow/server=default-server/http-listener=remoting:add(socket-binding=remoting, max-post-size="10485760", enable-http2="true")`

#### WSDL Location

On configure l'emplacement du WSDL:

`/subsystem=webservices:write-attribute(name=wsdl-host, value=jbossws.undefined.host)`

`/subsystem=webservices:write-attribute(name=modify-wsdl-address, value=true)`

`:reload`

#### Encodage URI

On configure l'encodage URI:

`/system-property=org.apache.catalina.connector.URI_ENCODING:remove()`

`/system-property=org.apache.catalina.connector.URI_ENCODING:add(value=UTF-8)`

`/system-property=org.apache.catalina.connector.USE_BODY_ENCODING_FOR_QUERY_STRING:remove()`

`/system-property=org.apache.catalina.connector.USE_BODY_ENCODING_FOR_QUERY_STRING:add(value=true)`

`:reload`


#### Dépannage de JBOSS

Quitter la CLI JBOSS.

`curl -o /opt/SignServer/xalan-2.7.2.jar -L https://repo1.maven.org/maven2/xalan/xalan/2.7.2/xalan-2.7.2.jar`

`curl -o /opt/SignServer/serializer-2.7.2.jar -L https://repo1.maven.org/maven2/xalan/serializer/2.7.2/serializer-2.7.2.jar`

`cp /opt/SignServer/xalan-2.7.2.jar /opt/SignServer/serializer-2.7.2.jar /opt/SignServer/wildfly-14.0.1.Final/modules/system/layers/base/org/apache/xalan/main/`

`sed -i 's/path="serializer-2.7.1.jbossorg-4.jar"/path="serializer-2.7.2.jar"/g' /opt/SignServer/wildfly-14.0.1.Final/modules/system/layers/base/org/apache/xalan/main/module.xml`

`sed -i 's/path="xalan-2.7.1.jbossorg-4.jar"/path="xalan-2.7.2.jar"/g' /opt/SignServer/wildfly-14.0.1.Final/modules/system/layers/base/org/apache/xalan/main/module.xml`

#### Configuration de la base de données

Télécharger le pilote de base de données MariaDB:

`curl -o /opt/SignServer/mariadb-java-client-2.1.0.jar -L https://downloads.mariadb.com/Connectors/java/connector-java-2.1.0/mariadb-java-client-2.1.0.jar`

Ajoutez le pilote de base de données MariaDB en le déployant à chaud dans le répertoire de déploiement:

`cp mariadb-java-client-2.1.0.jar /opt/SignServer/wildfly-14.0.1.Final/standalone/deployments/mariadb-java-client.jar`

Démarrer le CLI JBOSS:

`/opt/SignServer/wildfly-14.0.1.Final/bin/jboss-cli.sh -c`

Configure la data source (Si vous utilisez une base de données sur une machine différente, vous devez changer l'addresse IP et le numéro de port):

`data-source add --name=signserverds --driver-name="mariadb-java-client.jar" --connection-url="jdbc:mysql://127.0.0.1:3306/signserver" --jndi-name="java:/SignServerDS" --use-ccm=true --driver-class="org.mariadb.jdbc.Driver" --user-name="signserver" --password="signserver" --validate-on-match=true --background-validation=false --prepared-statements-cache-size=50 --share-prepared-statements=true --min-pool-size=5 --max-pool-size=150 --pool-prefill=true --transaction-isolation=TRANSACTION_READ_COMMITTED --check-valid-connection-sql="select 1;" --enabled=true`

`:reload`

## Partie II : Installation Automatique

## Partie III : Dockerisation

## Exploitation

## Conclusion


### Markdown

Markdown is a lightweight and easy-to-use syntax for styling your writing. It includes conventions for

```markdown
Syntax highlighted code block

# Header 1
## Header 2
### Header 3

- Bulleted
- List

1. Numbered
2. List

**Bold** and _Italic_ and `Code` text

[Link](url) and ![Image](src)
```

For more details see [GitHub Flavored Markdown](https://guides.github.com/features/mastering-markdown/).

