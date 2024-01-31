FROM rkrahl/opensuse:15.4

RUN zypper --non-interactive refresh

RUN zypper --non-interactive install \
	glibc-locale \
	java-11-openjdk-devel \
	mysql-connector-java-5.1.47 \
	unzip && \
    zypper --non-interactive addlock mysql-connector-java

ENV GLASSFISH_HOME /opt/payara5
ENV JAVA_HOME /usr/lib64/jvm/java-11-openjdk
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
	https://repo1.maven.org/maven2/fish/payara/distributions/payara/5.2022.5/payara-5.2022.5.zip && \
    unzip -q -d /opt $tmpfile && \
    rm -rf $tmpfile && \
    asadmin delete-domain domain1

CMD ["/etc/glassfish/start-glassfish.sh"]

VOLUME ["$GLASSFISH_HOME/glassfish/domains"]

EXPOSE 4848 8009 8080 8181
