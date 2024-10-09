FROM tomcat:9.0.95-jdk11-temurin

ENV JAVA_OPTS="$JAVA_OPTS -Dorg.apache.el.parser.SKIP_IDENTIFIER_CHECK=true"

# Editing context.xml, server.xml, startup.sh and tomcat-users.xml (with Docker secrets for manager user credentials)
RUN --mount=type=secret,id=tomcat_user,required \
    --mount=type=secret,id=tomcat_password,required \
    sed -i 's/<Context>/\n<Context\ sessionCookiePath="\/"\ useHttpOnly="false"\ clearReferencesStopTimerThreads="true">/' /usr/local/tomcat/conf/context.xml \
 && sed -i "75i \               URIEncoding=\"UTF-8\"" /usr/local/tomcat/conf/server.xml \
 && sed -i "75i \               useIPVHosts=\"true\"" /usr/local/tomcat/conf/server.xml \
 && sed -i "28s/.*/<Listener className=\"org.apache.catalina.core.AprLifecycleListener\" SSLEngine=\"on\" \/>/" /usr/local/tomcat/conf/server.xml \
 && tomcat_user=$(cat /run/secrets/tomcat_user); \
    tomcat_password=$(cat /run/secrets/tomcat_password); \
    sed -i "56i \    <user username=\"${tomcat_user}\" password=\"${tomcat_password}\" roles=\"manager-gui,manager-script\"/>" /usr/local/tomcat/conf/tomcat-users.xml \
 && sed -i "56i \    <user username=\"tomcat\" password=\"tomcat\" roles=\"manager-script,manager-jmx\"/>" /usr/local/tomcat/conf/tomcat-users.xml \
 && sed -i "56i \   <role rolename=\"manager-status\"/>" /usr/local/tomcat/conf/tomcat-users.xml \
 && sed -i "56i \   <role rolename=\"manager-gui\"/>" /usr/local/tomcat/conf/tomcat-users.xml \
 && sed -i "56i \   <role rolename=\"manager-jmx\"/>" /usr/local/tomcat/conf/tomcat-users.xml \
 && sed -i "56i \   <role rolename=\"manager-script\"/>" /usr/local/tomcat/conf/tomcat-users.xml \
 && sed -i "60s/.*/exec \"\$PRGDIR\"\/\"\$EXECUTABLE\" run \"\$@\"/" /usr/local/tomcat/bin/startup.sh

EXPOSE 8080

# Note: if out of memory: modify JVM heap size (TOMCAT_OPTS)
CMD ["catalina.sh", "run"]