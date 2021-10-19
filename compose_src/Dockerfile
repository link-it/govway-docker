FROM centos:centos7
ARG govway_branch=master

MAINTAINER Andrea Manca <manca@link.it>

USER root
RUN yum -q -y update \
&& yum -q -y install unzip telnet nmap-ncat wget java-11-openjdk openssl git java-11-openjdk-devel.x86_64 openssh openssh-server \
&& yum clean all \
&& wget -qO /usr/local/bin/gosu https://github.com/tianon/gosu/releases/download/1.11/gosu-amd64 \
&& chmod +x /usr/local/bin/gosu \
&& rm -rf /var/cache/yum

ENV LANG=it_IT.UTF-8 JAVA_HOME=/usr/lib/jvm/jre-11-openjdk ANT_VERSION=1.10.6 MAVEN_VERSION=3.6.3
ENV ANT_HOME=/opt/apache-ant-${ANT_VERSION}
ENV MVN_HOME=/opt/apache-maven-${MAVEN_VERSION}/
ENV PATH=$JAVA_HOME/bin:$ANT_HOME/bin:$MVN_HOME/bin:$PATH
RUN wget -qO -  http://mirror.nohup.it/apache/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz | tar -xzf- -C /opt \
&& wget -q https://downloads.apache.org//ant/binaries/apache-ant-${ANT_VERSION}-bin.zip -O /var/tmp/apache-ant-${ANT_VERSION}-bin.zip \
&& unzip -qq -d /opt/ /var/tmp/apache-ant-${ANT_VERSION}-bin.zip \
&& rm -f /var/tmp/apache-ant-${ANT_VERSION}-bin.zip
RUN echo "export LANG=${LANG}" >> /etc/profile \
&& echo "export LC_ALL=${LANG}" >> /etc/profile \
&& echo "export JAVA_HOME=${JAVA_HOME}" >> /etc/profile \
&& echo "export ANT_HOME=${ANT_HOME}" >> /etc/profile \
&& echo "export MVN_HOME=${MVN_HOME}" >> /etc/profile \
&& echo "export PATH=$JAVA_HOME/bin:$ANT_HOME/bin:$MVN_HOME/bin:$PATH" >> /etc/profile \
&& rm -f /etc/localtime \
&& ln -s /usr/share/zoneinfo/Europe/Rome /etc/localtime \
&& echo "LANG=${LANG}" > /etc/locale.conf

ENV TOMCAT_MAJOR_VERSION=9 TOMCAT_FULLVERSION=9.0.33
RUN wget -qO - https://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR_VERSION}/v${TOMCAT_FULLVERSION}/bin/apache-tomcat-${TOMCAT_FULLVERSION}.tar.gz | tar -xzf- -C /opt

ENV GOVWAY_HOME=/var/govway GOVWAY_LOGDIR=/var/govway/log GOVWAY_FULLVERSION=${govway_branch}
ADD https://api.github.com/repos/link-it/govway/git/refs/heads/${GOVWAY_FULLVERSION} version.json
RUN git clone -b ${GOVWAY_FULLVERSION} https://github.com/link-it/GovWay.git /opt/GovWay  \
&& cd /opt/GovWay \
&& sed -i -e 's#UPDATE_DOC=true#UPDATE_DOC=false#g' ./distrib/distrib.sh \
&& sed -i -e 's#AS_VERSION=wildfly10,tomcat7#AS_VERSION=tomcat7#g' \
 -e 's#DB_VERSION=postgresql,mysql,oracle,hsql,sqlserver,db2#DB_VERSION=postgresql#g' \
 ./ant/setup/prepare-build.properties \
&& mvn -Dowasp=none -Dcompile=none -Dpackage=package -Dtestsuite=none package \
&& bash -c 'archivio="$(ls -1 /opt/GovWay/dist/govway-installer-*.tgz 2>/dev/null)"; if [ -n "${archivio}" ]; then ln -s ${archivio//.tgz} '/opt/govway-installer-${GOVWAY_FULLVERSION}'; else exit 1; fi'


WORKDIR /opt/govway-installer-${GOVWAY_FULLVERSION}
COPY resources_compose/ant.install.properties.template /var/tmp/
RUN sed -i -r -e 's/ui="(.*)"/ui="\1,text-auto"/' -e "s/#GOVWAY_FULLVERSION#/${GOVWAY_FULLVERSION}/" installer/setup/antinstall-config.xml /var/tmp/ant.install.properties.template \
&& mv /var/tmp/ant.install.properties.template installer/setup/ \
&& ./install.sh text-auto > /tmp/govway_installer_log.txt 2>&1

RUN mkdir /database \
&& cat dist/sql/GovWay.sql dist/sql/GovWay_init.sql > /database/GovWay_setup.sql
ENV POSTGRES_JDBC_VERSION=42.2.10 HSQLDB_FULLVERSION=2.4.1
ENV CATALINA_HOME=/opt/apache-tomcat-${TOMCAT_FULLVERSION}
RUN wget -q -O /var/tmp/hsqldb-${HSQLDB_FULLVERSION}.zip https://sourceforge.net/projects/hsqldb/files/hsqldb/hsqldb_2_4/hsqldb-${HSQLDB_FULLVERSION}.zip/download \
&& unzip -q -d /opt /var/tmp/hsqldb-${HSQLDB_FULLVERSION}.zip hsqldb-${HSQLDB_FULLVERSION}/hsqldb/lib/* \
&& rm -f  /var/tmp/hsqldb-${HSQLDB_FULLVERSION}.zip \
&& wget -qO ${CATALINA_HOME}/lib/postgresql-${POSTGRES_JDBC_VERSION}.jar http://jdbc.postgresql.org/download/postgresql-${POSTGRES_JDBC_VERSION}.jar

COPY catalina_wrapper.sh genera_certs.sh ${CATALINA_HOME}/bin/
COPY ConnectorTLS_in_server.xslt resources_compose/server.xml resources_compose/context.xml resources_compose/Resource_in_server.xml.xslt resources_compose/ResourceLink_in_context.xml.xslt ${CATALINA_HOME}/conf/

RUN xsltproc ${CATALINA_HOME}/conf/Resource_in_server.xml.xslt ${CATALINA_HOME}/conf/server.xml > /var/tmp/server.xml  \
&& mv /var/tmp/server.xml ${CATALINA_HOME}/conf/server.xml \
&& xsltproc ${CATALINA_HOME}/conf/ResourceLink_in_context.xml.xslt ${CATALINA_HOME}/conf/context.xml > /var/tmp/context.xml \
&& mv /var/tmp/context.xml ${CATALINA_HOME}/conf/context.xml

WORKDIR ${CATALINA_HOME}


# USER tomcat # rilascio privilegi utenza root tramite gosu in catalina_wrapper.sh
ENV PATH=${CATALINA_HOME}/bin:${PATH}
ENV SKIP_DB_CHECK=FALSE
EXPOSE 8080 8443
ENTRYPOINT ["bin/catalina_wrapper.sh"]
CMD ["run"]
