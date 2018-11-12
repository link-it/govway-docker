FROM centos:centos7
ARG govway_fullversion=3.0.1.rc1

MAINTAINER Andrea Manca <manca@link.it>

USER root 
RUN yum -q -y install unzip telnet nmap-ncat wget java-1.8.0-openjdk-headless \
&& yum clean all \
&& rm -rf /var/cache/yum

ENV LANG=it_IT.UTF-8 JAVA_HOME=/usr/lib/jvm/jre-1.8.0-openjdk
ENV PATH=$JAVA_HOME/bin:$PATH
RUN echo "export LANG=${LANG}" >> /etc/profile \
&& echo "export JAVA_HOME=${JAVA_HOME}" >> /etc/profile \
&& echo "export PATH=${JAVA_HOME}/bin:$PATH" >> /etc/profile

ENV TOMCAT_MAJOR_VERSION=9 TOMCAT_FULLVERSION=9.0.12
RUN wget -qO - https://archive.apache.org/dist/tomcat/tomcat-${TOMCAT_MAJOR_VERSION}/v${TOMCAT_FULLVERSION}/bin/apache-tomcat-${TOMCAT_FULLVERSION}.tar.gz | tar -xzf- -C /opt 

ENV GOVWAY_HOME=/etc/govway/ GOVWAY_LOGDIR=/var/log/govway GOVWAY_FULLVERSION=${govway_fullversion}
RUN wget -qO - https://github.com/link-it/GovWay/releases/download/${GOVWAY_FULLVERSION}/govway-installer-${GOVWAY_FULLVERSION}.tgz | tar -xzf- -C /opt 


WORKDIR /opt/govway-installer-${GOVWAY_FULLVERSION}
COPY resources_compose/ant.install.properties.template /var/tmp/
RUN sed -i -r -e 's/ui="(.*)"/ui="\1,text-auto"/'  installer/setup/antinstall-config.xml \
&& mv /var/tmp/ant.install.properties.template installer/setup/ \
&& ./install.sh text-auto > /tmp/govway_installer_log.html 2>&1



RUN mkdir /database \
&& cat dist/sql/GovWay.sql dist/sql/GovWay_init.sql > /database/GovWay_setup.sql

ENV CATALINA_HOME=/opt/apache-tomcat-${TOMCAT_FULLVERSION}
COPY catalina_wrapper.sh ${CATALINA_HOME}/bin/
COPY resources_compose/server.xml resources_compose/context.xml resources_compose/Resource_in_server.xml.xslt resources_compose/ResourceLink_in_context.xml.xslt ${CATALINA_HOME}/conf/

RUN xsltproc ${CATALINA_HOME}/conf/Resource_in_server.xml.xslt ${CATALINA_HOME}/conf/server.xml > /var/tmp/server.xml  \
&& mv /var/tmp/server.xml ${CATALINA_HOME}/conf/server.xml \
&& xsltproc ${CATALINA_HOME}/conf/ResourceLink_in_context.xml.xslt ${CATALINA_HOME}/conf/context.xml > /var/tmp/context.xml \
&& mv /var/tmp/context.xml ${CATALINA_HOME}/conf/context.xml

ENV POSTGRES_JDBC_VERSION=42.2.5
RUN groupadd -r tomcat \
&& useradd -r --create-home -g tomcat tomcat \
&& mkdir ${GOVWAY_HOME} ${GOVWAY_LOGDIR} \
&& rm -rf ${CATALINA_HOME}/webapps/* \
&& cp dist/cfg/*.properties ${GOVWAY_HOME} \
&& cp dist/archivi/*.war ${CATALINA_HOME}/webapps \
&& wget -qO ${CATALINA_HOME}/lib/postgresql-${POSTGRES_JDBC_VERSION}.jar http://jdbc.postgresql.org/download/postgresql-${POSTGRES_JDBC_VERSION}.jar \
&& chown -R tomcat.tomcat ${GOVWAY_HOME} ${GOVWAY_LOGDIR} ${CATALINA_HOME} /database

WORKDIR ${CATALINA_HOME}
USER tomcat
ENV PATH=${CATALINA_HOME}/bin:${PATH}
ENV SKIP_DB_CHECK=FALSE
CMD ["bin/catalina_wrapper.sh","run"]

