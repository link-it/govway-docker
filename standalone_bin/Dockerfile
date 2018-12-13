FROM centos:centos7
ARG govway_fullversion=3.0.1.rc2

MAINTAINER Andrea Manca <manca@link.it>

USER root 
RUN yum -q -y install unzip telnet nmap-ncat wget java-1.8.0-openjdk openssl \
&& yum clean all \
&& wget -qO /usr/local/bin/gosu https://github.com/tianon/gosu/releases/download/1.11/gosu-amd64 \
&& chmod +x /usr/local/bin/gosu \
&& rm -rf /var/cache/yum

ENV LANG=it_IT.UTF-8 JAVA_HOME=/usr/lib/jvm/jre-1.8.0-openjdk
ENV PATH=$JAVA_HOME/bin:$PATH
RUN echo "export LANG=${LANG}" >> /etc/profile \
&& echo "export JAVA_HOME=${JAVA_HOME}" >> /etc/profile \
&& echo "export PATH=${JAVA_HOME}/bin:$PATH" >> /etc/profile \
&& rm -f /etc/localtime \
&& ln -s /usr/share/zoneinfo/Europe/Rome /etc/localtime

ENV TOMCAT_MAJOR_VERSION=9 TOMCAT_FULLVERSION=9.0.12
RUN wget -qO - https://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR_VERSION}/v${TOMCAT_FULLVERSION}/bin/apache-tomcat-${TOMCAT_FULLVERSION}.tar.gz | tar -xzf- -C /opt 

ENV HSQLDB_FULLVERSION 2.4.1
RUN wget -q -O /var/tmp/hsqldb-${HSQLDB_FULLVERSION}.zip https://sourceforge.net/projects/hsqldb/files/hsqldb/hsqldb_2_4/hsqldb-${HSQLDB_FULLVERSION}.zip/download \
&& unzip -q -d /opt /var/tmp/hsqldb-${HSQLDB_FULLVERSION}.zip hsqldb-${HSQLDB_FULLVERSION}/hsqldb/lib/* \
&& rm -f  /var/tmp/hsqldb-${HSQLDB_FULLVERSION}.zip

ENV GOVWAY_HOME=/var/govway GOVWAY_LOGDIR=/var/govway/log GOVWAY_FULLVERSION=${govway_fullversion}
RUN wget -qO - https://github.com/link-it/GovWay/releases/download/${GOVWAY_FULLVERSION}/govway-installer-${GOVWAY_FULLVERSION}.tgz | tar -xzf- -C /opt 


WORKDIR /opt/govway-installer-${GOVWAY_FULLVERSION}
COPY resources_standalone/ant.install.properties.template /var/tmp/
RUN sed -i -r -e 's/ui="(.*)"/ui="\1,text-auto"/'  installer/setup/antinstall-config.xml \
&& mv /var/tmp/ant.install.properties.template installer/setup/ \
&& ./install.sh text-auto > /tmp/govway_installer_log.txt 2>&1

RUN mkdir /database \
&& cat /opt/govway-installer-${GOVWAY_FULLVERSION}/dist/sql/GovWay.sql /opt/govway-installer-${GOVWAY_FULLVERSION}/dist/sql/GovWay_init.sql > /database/GovWay_setup.sql


ENV CATALINA_HOME=/opt/apache-tomcat-${TOMCAT_FULLVERSION}
COPY catalina_wrapper.sh genera_certs.sh ${CATALINA_HOME}/bin/
COPY ConnectorTLS_in_server.xslt resources_standalone/server.xml resources_standalone/context.xml ${CATALINA_HOME}/conf/

WORKDIR ${CATALINA_HOME}


# USER tomcat # rilascio privilegi utenza root tramite gosu in catalina_wrapper.sh
ENV PATH=${CATALINA_HOME}/bin:${PATH}
ENV SKIP_DB_CHECK=TRUE
EXPOSE 8080 8443
CMD ["bin/catalina_wrapper.sh","run"]

