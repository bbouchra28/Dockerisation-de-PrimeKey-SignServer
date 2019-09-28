1. [ Introduction. ](#intr)
2. [ Préparation. ](#prp)
3. [ Partie I Installation Manuelle. ](#man)
4. [ Partie II Installation Automatique. ](#aut)
5. [ Partie III Dockerisation. ](#doc)
6. [ Exploitation. ](#exp)
7. [ Conclusion. ](#cnc)

<a name="intr"></a>
## Introduction

<a name="prp"></a>
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
- Un compte avec des privilèges Sudo

<a name="man"></a>
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

`CREATE DATABASE signserver;

GRANT ALL PRIVILEGES ON signserver.* TO signserver@localhost IDENTIFIED BY 'signserver';`

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

### Installation de SignServer

Dans cette étape on installe SignServer CE, on commence par la définition des variables d'environnement de notre bash shell.

`export APPSRV_HOME=/opt/SignServer/wildfly-14.0.1.Final`

`export SIGNSERVER_NODEID=node1`

Puis on prépare les fichiers de configuration:

`cd /opt/SignServer/signserver-ce-5.0.0.Final`

Pour ce tuto, on va utiliser la configuration par défaut fournit par PrimeKey (vous pouvez modifier la configuration selon vos besoins).

`cp conf/server_deploy.properties.sample conf/signserver_deploy.properties`

On déploie le SignServer sur le serveur WildFly

`bin/ant deploy`

On vérifier que signserver.ear.deployed

`ls /opt/wildfly/standalone/deployments | grep signserver.ear*`

Enfin on test si SignServer a été déployer correctement:

`bin/signserver getstatus brief all`

`Current version of server is: SignServer CE 5.0.0`


<a name="aut"></a>
## Partie II : Installation Automatique

Maintenant qu'on a installé SignServer manuellement passons à l'étape suivante et automatisons l'ensemble du processus.

On aura besoin de créer les fonctions bash suivantes:

- **init_mariadb()**         : Supprime les tables de SignServer de la base de données.
- **create_mariadb_index()** : Crée les tables nécessaire pour le fonctionnement de SignServer.
- **backup_mariadb()**       : Sauvegarde la base de données une fois l'installation est finie.
- **wildfly_killall()**      : Cette fonction est violente, elle sert a arrêter tout les processus de WildFly. 
- **wildfly_exec()**         : Execute les commande de WildFly.
- **wildfly_reload()**       : Redémarre WildFly.
- **wildfly_check()**        : Vérifie si WildFly est démarré correctement.
- **wildfly_keystore()**     : Créer le répertoire Keystore et copie dedans le keystore.jks et le magasin de confiance truststore.jks.
- **download()**             : Télécharge SignServer, WildFly, Pilote MariaDB, le JAR XALAN et SERIALIZER.
- **config_wildfly()**       : Configure TLS, HTTP, Emplacement WSDL, Encodage URI et la base de données.
- **deploy_signserver()**    : Déploie SignServer.

Le script est disponible sur [ce lien](https://github.com/bbouchra28/Dockerisation-de-PrimeKey-SignServer/blob/master/signserver_install.sh)

Pour l'utiliser:

`bash signserver_install.sh $database_host $database_port $database_name $database_username $database_password`


<a name="doc"></a>
## Partie III : Dockerisation

Dans cette partie on va construire l'image docker de SignServer, on aura besoin des éléments suivants :

- **mariadb-compose.yml**    : Permet de lancer un conteneur de base de données mariadb.
- **Dockerfile**             : Ce fichier permet à docker de construire l'image en lisant les instructions écrite dans ce fichier.
- **signserver_install.sh**  : Le script d'installation automatique utilisé dans la partie principale.
- **init.sh**                : Ce script permet d'initialiser les conteneurs utilisant l'image SignServer.


### mariadb-compose.yml

Avant de lancer la construction de l'image docker, on doit avoir une base de données mariadb.
Pour cela on utilise docker-compose pour lancer un conteneur mariadb contenant une base de données nommé signserver avec un utilisateur nommé signserver et son mot de passe est signserver.

De plus on crée un réseau 10.5.0.0/16, on attribue l'adresse 10.5.0.3 au conteneur, et on map le port 3306 sur 9999 de notre machine physique.

Enfin nous avons un volume pour persister les données stocker sur mariadb.

On lance la base de données avant de construire l'image:

`docker-compose -f mariadb-compose.yml up -d`

### Dockerfile

Pour le processus de dockerisation nous allons baser notre construction sur une image debian 9.7.

Tout d'abord une crée une couche à partir de l'image debian:9.7 disponible sur le docker-hub :

`FROM debian:9.7` 

Ensuite on installe les outils nécessaire pour l'installation (unzip, ant, curl, wget, openjdk-8 ... ):

`RUN apt-get update && apt-get install -y unzip ant ant-optional psmisc bc patch openjdk-8-jdk-headless wget gnupg2 curl mariadb-server`

Puis on copie le fichier d'installation automatique dans /opt:

`COPY ./signserver_install.sh /opt`

on se met sur /opt et on exécute le script, on donne l'adresse IP du passerelle (la machine physique) et le port 9999 :

`WORKDIR /opt`

`RUN bash signserver_install.sh 10.5.0.1 9999 signserver signserver signserver`

Une fois l'installtion est finie on copie le script d'intialisation, on le transforme en exécutable et on le met en Entrypoint (c'est à dire init.sh sera éxécuté une fois le conteneur est démarré).

`COPY ./init.sh  /opt`

`RUN chmod +x /opt/init.sh`

`ENTRYPOINT "./init.sh"`

### signserver_install.sh 

On utilise le script d'installation automatique de SignServer pour installer et configurer SignServer et Wildfly sur l'image docker.


### init.sh

l'objectif de cet script est d'intialiser le conteneur, il le fait comme suit :

- Récupére les variables d'environnement (nom d'utilisateur de la base, son mot de de passe, adresse IP de la base, le numéro de port, le nom de la base et une variable pour préciser si on la base de données est vide ou elle contient déjà des données).

- Si le conteneur n'a jamais été initialisé, il modifier les paramètres de la base de données dans le fichier standalone.xml (utilisateur, mot de passe, url vers la base).

- Crée les données nécessaire pour le fonctionnement de SignServer (si on utilise une base de données vide).  

- Lance Wildfly et crée un fichier nommé init, ce dernier sert à dire que ce conteneur a été déjà initialisé.

- Si le fichier init existe, le script conclu que le conteneur a été déjà intialisé et démarre WildFly.

## Lancement de conteneur SignServer

Une fois la construction de l'image est fini, on peut maintenant l'utiliser pour lancer des conteneurs SignServer.

Le fichier [signserver-compose.yml](https://github.com/bbouchra28/Dockerisation-de-PrimeKey-SignServer/blob/master/signserver-compose.yml) permet de lancer un conteneur SignServer sur l'adresse IP 10.5.0.3 avec les variables d'environnement nécessaires.

Avant de lancer le conteneur SignServer, on doit assurer que notre base de données est live et disponible, pour être sure on peut faire `netstat/ss -ntlp` ou de re-exécuter la commande :

`docker-compose -f mariadb-compose.yml up -d`

Et puis on lance notre conteneur SignServer:

`docker-compose -f SignServer.yml up -d`

On vérifie les logs pour assurer que WildFly a été correctement démarré :

`docker logs -f sign`

Allons à l'intérieur du conteneur pour vérifier que tout marche bien :

`docker exec -it sign bash`

`cd signserver`

`bin/signserver getsatus brief all`

Resultat : `Current version of server is : SignServer CE 5.0.0.Final`


<a name="exp"></a>
## Exploitation

### Configuration d'un Worker PDFSigner

On se met à l'interieur du conteneur SignServer:

`docker exec -it sign bash`

Tout d'abord on configure un CryotoTokenP12  en utilisant l'exemple de fichier de configuration fournit par PrimeKey.

`bin/signserver setproperties doc/sample-configs/keystore-crypto.properties`

Ensuite on met à jour la propriété KEYSTOREPATH du CryptoToken pour qu'elle pointe vers un magasin de clés PKCS # 12 contenant les clés et le certificat appropriés pour la signature des documents (on utilise le p12 fournit par PrimeKey à des fins de test seulement)
<pre>
bin/signserver setproperty 1 KEYSTOREPATH /opt/wildfly/res/test/dss10/dss10_keystore.p12

bin/signserver setproperty 1 KEYSTOREPASSWORD foo123

bin/signserver setproperty 1 DEFAULTKEY "signer00003"

bin/signserver reload 1
</pre>

Maintenant qu'on notre p12 en place, on passe à la configuration du Worker PDFSigner:

`bin/signserver setproperties doc/sample-configs/pdfsigner.properties`

Puis on active la configuration:

`bin/signserver reload 1`

Enfin on test que tout les Worker sont up and running:

`bin/signserver getstatus complete all`

### Création d'un client HTTP

Dans cette partie on utilise python3 pour envoyer une requête http contenant un pdf à signer au SignServer.

On utilise les libs suivantes:
<pre>
import requests

import argparse
</pre>
On définit les flags (`--pdf`, `--host`, `--password`, `--worker`):
<pre>
parser = argparse.ArgumentParser()

parser.add_argument("--pdf" , help="Le fichier pdf a signer, chemin absolue")

parser.add_argument("--host" , help="url vers SignServer")

parser.add_argument("--password" , help="mot de passe de pdf s'il est protégé")

parser.add_argument("--worker" , help="Id du worker")

args = parser.parse_args()
</pre>

Si le pdf n'est pas protégé password doit contenir une chaine vide:
<pre>
if [args.password]:

   password = args.password

else:

   password = ""
</pre>
Les paramètres de la requête:
<pre>
params = {

                            'workerName': 'PDFSigner'       ,
                            
                            'workerId': args.worker         ,
                            
                            'pdfPassword': password         ,
                            
                            'processType': 'signDocument'   ,
                            
        }
</pre>

Le fichier à signer et l'url vers le SignServer:

`pdffiles = {'filerecievefile': open(args.pdf, 'rb') }`

`url = args.host + '/signserver/process'`

On envoie la requête HTTP:

`r = requests.post(url, data=params, files=pdffiles)`

On récupère le pdf fichier et on le sauvegarde de `out.pdf`:

`file = open("out.pdf", "wb")`
`file.write(r.content)`
`file.close()`

Le script entier est disponible sur ce [lien](https://github.com/bbouchra28/Dockerisation-de-PrimeKey-SignServer/blob/master/Clients/HttpSignRequest.py).

On essaye le script avec un pdf non protégé:

`python3 HttpSignRequest.py --pdf="mypdf.pdf" --host="http://10.5.0.1:9005" --worker=2 `

Maintenant avec un pdf protégé:

`python3 HttpSignRequest.py --pdf="mypdf.pdf" --host="http://10.5.0.1:9005" --worker=2  --password="foo123"`


### Création d'un client WS

Aller maintenant on joue avec le service WSDL(Web Services Description Language) de SignServer.

On peut trouver ClientWS?wsdl sur l'url suivant http://<SignServer>/signserver/ClientWSService/ClientWS?wsdl.

On peut utilise le plugin chrome Wizdler pour voir les service disponibles, SignServeur expose deux service ProcessData et ProcessSOD.

On n'est pas intéressé par les e-passeport donc le service qui nous intéresse est ProcessData.

Voici un exemple de requête SOAP pour signer un pdf sur SignServer: [SoapRequest](https://imgur.com/lVjvZbT).


#### Python zeep

Afin d'automatiser l'envoie des requête SOAP, on utilise la librarie python-zeep pour créer un script d'automatisation.

On utilise les libraries suivantes:

`from zeep import Client`

`import argparse`

Donc on doit installer zeep:

`pip3 install zeep`

Si vous n'avez pas pip3 :

`apt install python3-pip`

Ensuite on met les flags nécessaire:
<pre>
parser = argparse.ArgumentParser() 

parser.add_argument("--pdf" , help="Le fichier pdf a signer, chemin absolue")

parser.add_argument("--wsdl" , help="url vers SignServer")

parser.add_argument("--password" , help="mot de passe de pdf s'il est protégé")

args = parser.parse_args()
</pre>
Si le pdf n'est pas protégé on aura pas besoin de password:
<pre>
if [args.password]:

	password = args.password
 
else:

	password = ""
 </pre>
Ensuite, on définit le Worker : `worker="PDFSigner"`

Puis, on récupère le fichier en binaire:
 <pre>
 with open(args.pdf, "rb") as file:

     data = file.read()
 </pre>
On définit le client: `client = Client(wsdl=args.wsdl)`.

On récupère le type metadata et on crée un objet de ce type contenant le mot de passe de pdf:
<pre>
metadata_type = client.get_type('ns0:metadata')

metadata = metadata_type(password,'pdfPassword')
</pre>
On envoie la requete : `result = client.service.processData(worker,metadata,data)`

Enfin on récupère le resultat:
<pre>
print("Archive ID: ", result.archiveId)

print("Metadata :", result.metadata)

print("Request ID ",result.requestId)

print("Signer's Certificates", result.signerCertificate.hex())

file = open("out.pdf", "wb")

file.write(result.data)

file.close()
</pre>

Le script entier est disponible sur ce [lien](https://github.com/bbouchra28/Dockerisation-de-PrimeKey-SignServer/blob/master/Clients/SignServerWSClient.py).

On essaye le script avec un pdf non protégé:

`python3 SignServerWSClient.py --pdf=mypdf.pdf --wsdl="http://10.5.0.1:9005/signserver/ClientWSService/ClientWS?wsdl"`

Maintenant avec un pdf protégé:

`python3 SignServerWSClient.py --pdf=myprotectedpdf.pdf --password=foo123 --wsdl="http://10.5.0.1:9005/signserver/ClientWSService/ClientWS?wsdl"`

<a name="cnc"></a>
## Conclusion


