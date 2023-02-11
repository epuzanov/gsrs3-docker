FROM maven:3-jdk-11 as build
    ENV MAVEN_CONFIG=
    ENV CATALINA_HOME=/usr/local/tomcat
    ARG GSRS_VER=3.0.3-SNAPSHOT
    ARG GSRS_TAG=GSRSv3.0.3PUB
    ARG EP_EXT_TAG=GSRSv3.0.3PUB
    #ARG MODULE_IGNORE="adverse-events applications clinical-trials products"
    ARG MODULE_IGNORE=

    COPY . /src
    # Install EP Extensions
    RUN [ -z "EP_EXT_TAG" ] && exit 0 ; \
        git clone --recursive --depth=1 --branch ${EP_EXT_TAG} https://github.com/epuzanov/gsrs-ep-substance-extension.git && \
        cd gsrs-ep-substance-extension && \
        sh ./mvnw clean -U install -DskipTests && \
        cd ..

    RUN git clone --recursive --depth=1 --branch ${GSRS_TAG} https://github.com/ncats/gsrs3-main-deployment.git && \
        cd gsrs3-main-deployment && \
        [ -z "EP_EXT_TAG" ] && rm -rf /src/patches/30-gsrsEpExtension.patch ; \
        apt-get update && apt-get install -y --no-install-recommends patch && [ -d /src/patches ] && find /src/patches -type f -name '*.patch' -print0 -exec patch -p1 -i {} \; ; \
        mkdir -p ${CATALINA_HOME}/conf/Catalina/localhost ${CATALINA_HOME}/webapps && \
        rm -rf ${MODULE_IGNORE} && \
        for module in `ls -1` ; do \
            [ ! -f ${module}/mvnw ] && continue ; \
            cd ${module} && \
            sh ./mvnw clean -U package -DskipTests && \
            unzip ./target/${module}.war.original -d ${CATALINA_HOME}/webapps/${module} && \
            mkdir -p ${CATALINA_HOME}/work/Catalina/localhost/${module} && \
            cd .. && \
            rm -rf ${module} ; done && \
        [ -d ${CATALINA_HOME}/webapps/substances ] && jar xf ${CATALINA_HOME}/webapps/substances/WEB-INF/lib/gsrs-module-substances-core-${GSRS_VER}.jar logback-spring.xml.backup ; \
        [ -f logback-spring.xml.backup ] && sed -i "s/\$.user.dir.\/logs/\$\{LOGS\}/g" logback-spring.xml.backup ; \
        [ -f logback-spring.xml.backup ] && sed -i "s/\$.user.dir./\$\{LOGS\}/g" logback-spring.xml.backup ; \
        [ -f logback-spring.xml.backup ] && sed -i "s/INFO,DEBUG,WARN,ERROR/\$\{log.level:-info\}/g" logback-spring.xml.backup ; \
        [ -f logback-spring.xml.backup ] && mv logback-spring.xml.backup ${CATALINA_HOME}/webapps/substances/WEB-INF/classes/logback-spring.xml ; \
        [ -d ${CATALINA_HOME}/webapps/gateway ] && mv ${CATALINA_HOME}/webapps/gateway ${CATALINA_HOME}/webapps/ROOT ; \
        [ -d ${CATALINA_HOME}/work/Catalina/localhost/gateway ] && mv ${CATALINA_HOME}/work/Catalina/localhost/gateway ${CATALINA_HOME}/work/Catalina/localhost/ROOT ; \
        cd ..

    # Remove duplicated JAR files
    RUN [ ! -d ${CATALINA_HOME}/webapps/substances ] && exit 0 ; \
        cd ${CATALINA_HOME}/webapps && \
        for context in `ls -1 | grep -v substances` ; do \
            for file in `ls -1 ${context}/WEB-INF/lib` ; do \
                [ ! -f substances/WEB-INF/lib/${file} ] && continue ; \
                rm ${context}/WEB-INF/lib/${file} && \
                ln -s ../../../substances/WEB-INF/lib/${file} ${context}/WEB-INF/lib/${file} ; done ; done

    # config.json fix
    RUN [ -f ${CATALINA_HOME}/webapps/frontend/WEB-INF/classes/static/assets/data/config.json ] && sed -i "s/http:..localhost:8081//g" ${CATALINA_HOME}/webapps/frontend/WEB-INF/classes/static/assets/data/config.json

    # Additional context configurations
    RUN [ ! -d ${CATALINA_HOME}/webapps/substances ] && exit 0 ; \
        [ -f ${CATALINA_HOME}/webapps/substances/META-INF/context.xml ] && exit 0 ; \
        cd ${CATALINA_HOME}/webapps && \
        echo '<Context docBase="substances">' > substances/META-INF/context.xml && \
        echo '    <Valve className="org.apache.catalina.valves.RemoteAddrValve" allow="${gateway.allow.pattern:-\d+\.\d+\.\d+\.\d+}"/>' >> substances/META-INF/context.xml && \
        echo '    <Resources allowLinking="true" className="org.apache.catalina.webresources.StandardRoot">' >> substances/META-INF/context.xml && \
        echo '        <PreResources className="org.apache.catalina.webresources.DirResourceSet" base="${user.dir}/conf" internalPath="/" webAppMount="/WEB-INF/classes" />' >> substances/META-INF/context.xml && \
        echo '    </Resources>' >> substances/META-INF/context.xml && \
        echo '</Context>' >> substances/META-INF/context.xml && \
        for context in `ls -1 | grep -v substances` ; do sed "s/substances\"/"${context}"\"/g" substances/META-INF/context.xml > ${context}/META-INF/context.xml ; done && \
        [ -f frontend/META-INF/context.xml ] && sed -i "s/<Resources/<Resources cacheMaxSize=\"40960\"/g" frontend/META-INF/context.xml ; \
        [ -f ROOT/META-INF/context.xml ] && sed -i "2d" ROOT/META-INF/context.xml

FROM tomcat:9-jre11
    ENV CATALINA_HOME=/usr/local/tomcat
    RUN rm -rf ${CATALINA_HOME}/temp && \
        /bin/echo -e "#!/bin/sh\nmkdir -p /home/srs/conf /home/srs/logs /home/srs/exports\ncd /home/srs\nexec \"\$@\"\n" > /entrypoint.sh && \
        chmod 755 /entrypoint.sh && \
        sed -i "s/logs/\/home\/srs\/logs/g" ${CATALINA_HOME}/conf/server.xml && \
        sed -i "s/connectionTimeout/maxPostSize=\"536870912\" relaxedQueryChars=\"[]|{}\" connectionTimeout/g" ${CATALINA_HOME}/conf/server.xml && \
        sed -i "s/unpackWARs=\"true\" autoDeploy=\"true\"/unpackWARs=\"false\" autoDeploy=\"false\" deployIgnore=\"\$\{deploy.ignore.pattern:-(adverse-events|applications|clinical-trials|impurities|products)\}\"/g" ${CATALINA_HOME}/conf/server.xml && \
        sed -i "s/\$.catalina.base././g" ${CATALINA_HOME}/conf/logging.properties && \
        mkdir -p /root/.cache/JNA /root/.java/fonts /home/srs/conf /home/srs/logs /home/srs/exports && \
        ln -s /tmp /root/.cache/JNA/temp && \
        ln -s /tmp /root/.java/fonts && \
        ln -s /tmp ${CATALINA_HOME}/temp
    COPY --from=build --chown=root ${CATALINA_HOME} ${CATALINA_HOME}
    WORKDIR /home/srs
    ENTRYPOINT [ "/entrypoint.sh" ]
    CMD ["catalina.sh", "run"]
