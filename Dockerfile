FROM rkrahl/opensuse:15.1

RUN zypper --non-interactive install \
	glibc-locale \
	java-1_8_0-openjdk-devel \
	unzip

# The distributed mysql-connector-java in opensuse:15.0 does not work
# with java-1_8_0-openjdk any more.  (A bug?)  Use the RPM from
# opensuse:42.3 instead.
COPY mysql-connector-java-5.1.42-10.3.1.noarch.rpm /tmp
RUN zypper --non-interactive install \
	/tmp/mysql-connector-java-5.1.42-10.3.1.noarch.rpm && \
    zypper --non-interactive addlock mysql-connector-java && \
    rm /tmp/mysql-connector-java-5.1.42-10.3.1.noarch.rpm

ENV GLASSFISH_HOME /opt/payara41
ENV JAVA_HOME /usr/lib64/jvm/java-1.8.0-openjdk
ENV LC_ALL en_US.UTF-8

RUN groupadd -r -g 800 glassfish && \
    useradd -r -u 800 -g glassfish -d $GLASSFISH_HOME -s /sbin/nologin \
	-c "GlassFish JavaEE application server" glassfish && \
    mkdir -p \
	$GLASSFISH_HOME \
	/etc/glassfish \
	/etc/glassfish/post-install.d \
	/etc/glassfish/post-startup.d
COPY start-glassfish.sh /etc/glassfish
RUN chmod 0755 /etc/glassfish/start-glassfish.sh && \
    chown -R glassfish:glassfish $GLASSFISH_HOME /etc/glassfish

USER glassfish
WORKDIR $GLASSFISH_HOME

ENV PATH $GLASSFISH_HOME/bin:$JAVA_HOME/bin:/usr/local/bin:/usr/bin:/bin

RUN tmpfile=`mktemp` && \
    curl --silent --show-error --location --output $tmpfile \
	https://repo1.maven.org/maven2/fish/payara/distributions/payara/4.1.2.181/payara-4.1.2.181.zip && \
    unzip -q -d /opt $tmpfile && \
    rm -rf $tmpfile && \
    asadmin delete-domain domain1

CMD ["/etc/glassfish/start-glassfish.sh"]

VOLUME ["$GLASSFISH_HOME/glassfish/domains"]

EXPOSE 4848 8009 8080 8181
