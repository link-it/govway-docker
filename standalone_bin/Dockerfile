FROM centos:centos7
ARG govway_fullversion=3.3.4.p2

MAINTAINER Andrea Manca <manca@link.it>

USER root
RUN yum -q -y install unzip telnet nmap-ncat wget java-11-openjdk openssl openssh openssh-server \
&& yum clean all \
&& wget -qO /usr/local/bin/gosu https://github.com/tianon/gosu/releases/download/1.11/gosu-amd64 \
&& chmod +x /usr/local/bin/gosu \
&& rm -rf /var/cache/yum

ENV LANG=it_IT.UTF-8 JAVA_HOME=/usr/lib/jvm/jre-11-openjdk
ENV PATH=$JAVA_HOME/bin:$PATH
RUN echo "export LANG=${LANG}" >> /etc/profile \
&& echo "export LC_ALL=${LANG}" >> /etc/profile \
&& echo "export JAVA_HOME=${JAVA_HOME}" >> /etc/profile \
&& echo "export PATH=${JAVA_HOME}/bin:$PATH" >> /etc/profile \
&& rm -f /etc/localtime \
&& ln -s /usr/share/zoneinfo/Europe/Rome /etc/localtime \
&& echo "LANG=${LANG}" > /etc/locale.conf

ENV TOMCAT_MAJOR_VERSION=9 TOMCAT_FULLVERSION=9.0.33

RUN wget -qO - https://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR_VERSION}/v${TOMCAT_FULLVERSION}/bin/apache-tomcat-${TOMCAT_FULLVERSION}.tar.gz | tar -xzf- -C /opt

ENV GOVWAY_HOME=/var/govway GOVWAY_LOGDIR=/var/govway/log GOVWAY_FULLVERSION=${govway_fullversion}

COPY resources_standalone/ant.install.properties.template /var/tmp/

RUN wget -qO - https://github.com/link-it/GovWay/releases/download/${GOVWAY_FULLVERSION}/govway-installer-${GOVWAY_FULLVERSION}.tgz | tar -xzf- -C /opt \
&& cd /opt/govway-installer-${GOVWAY_FULLVERSION} \
&& sed -i -r -e 's/ui="(.*)"/ui="\1,text-auto"/' -e "s/#GOVWAY_FULLVERSION#/${GOVWAY_FULLVERSION}/" installer/setup/antinstall-config.xml /var/tmp/ant.install.properties.template \
&& mv /var/tmp/ant.install.properties.template installer/setup/ \
&& ./install.sh text-auto > /tmp/govway_installer_log.txt 2>&1 \
&& rm -rf /opt/govway-installer-${GOVWAY_FULLVERSION}/installer /opt/govway-installer-${GOVWAY_FULLVERSION}/install.* /opt/govway-installer-${GOVWAY_FULLVERSION}/doc

RUN mkdir /database \
&& cat /opt/govway-installer-${GOVWAY_FULLVERSION}/dist/sql/GovWay.sql /opt/govway-installer-${GOVWAY_FULLVERSION}/dist/sql/GovWay_init.sql > /database/GovWay_setup.sql

ENV POSTGRES_JDBC_VERSION=42.2.10 HSQLDB_FULLVERSION=2.4.1
ENV CATALINA_HOME=/opt/apache-tomcat-${TOMCAT_FULLVERSION}
RUN wget -q -O /var/tmp/hsqldb-${HSQLDB_FULLVERSION}.zip https://sourceforge.net/projects/hsqldb/files/hsqldb/hsqldb_2_4/hsqldb-${HSQLDB_FULLVERSION}.zip/download \
&& unzip -q -d /opt /var/tmp/hsqldb-${HSQLDB_FULLVERSION}.zip hsqldb-${HSQLDB_FULLVERSION}/hsqldb/lib/* \
&& rm -f  /var/tmp/hsqldb-${HSQLDB_FULLVERSION}.zip

COPY catalina_wrapper.sh genera_certs.sh ${CATALINA_HOME}/bin/
COPY ConnectorTLS_in_server.xslt resources_standalone/server.xml resources_standalone/context.xml ${CATALINA_HOME}/conf/

WORKDIR ${CATALINA_HOME}


# USER tomcat # rilascio privilegi utenza root tramite gosu in catalina_wrapper.sh
ENV PATH=${CATALINA_HOME}/bin:${PATH}
ENV SKIP_DB_CHECK=TRUE
EXPOSE 8080 8443
ENTRYPOINT ["bin/catalina_wrapper.sh"]
CMD ["run"]
