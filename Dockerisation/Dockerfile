FROM debian:9.7 

RUN apt-get update && apt-get install -y \
	unzip \
	ant \
	ant-optional \
	psmisc \
	bc \
	patch \
	openjdk-8-jdk-headless \
	wget \
        gnupg2 \
	curl \
	mariadb-server 

COPY ./signserver_install.sh /opt


WORKDIR /opt

RUN bash signserver_install.sh 10.5.0.1 9999 signserver signserver signserver

RUN ls /opt/wildfly/standalone/deployments

COPY ./init.sh  /opt
RUN chmod +x /opt/init.sh

ENTRYPOINT "./init.sh"
