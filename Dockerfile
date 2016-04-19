FROM opensuse

ENV GLASSFISH_HOME /opt/glassfish4
ENV JAVA_HOME /usr/lib64/jvm/java-1.8.0-openjdk
ENV PATH $GLASSFISH_HOME/bin:$JAVA_HOME/bin:/usr/local/bin:/usr/bin:/bin 

RUN zypper --non-interactive modifyrepo --disable non-oss update-non-oss
RUN zypper --non-interactive install \
	curl \
	java-1_8_0-openjdk-devel \
	net-tools \
	pwgen \
	unzip

RUN /usr/sbin/groupadd -r glassfish && \
    /usr/sbin/useradd -r -g glassfish -d $GLASSFISH_HOME -s /sbin/nologin \
	-c "GlassFish JavaEE application server" glassfish && \
    /usr/bin/mkdir -p $GLASSFISH_HOME && \
    /usr/bin/chown glassfish:glassfish $GLASSFISH_HOME

USER glassfish
WORKDIR $GLASSFISH_HOME

RUN tmpfile=`mktemp` && \
    curl --silent --show-error --location --output $tmpfile \
	http://download.java.net/glassfish/4.0/release/glassfish-4.0.zip && \
    unzip -q -d /opt $tmpfile && \
    rm -rf $tmpfile

EXPOSE 4848 8080 8181
CMD asadmin start-domain --verbose
