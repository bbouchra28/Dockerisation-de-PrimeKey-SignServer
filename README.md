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

