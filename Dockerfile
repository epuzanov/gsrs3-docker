FROM maven:3-jdk-11 as build
    ENV MAVEN_CONFIG=
    ENV CATALINA_HOME=/usr/local/tomcat
    ARG GSRS_VER=3.1.1
    ARG GSRS_TAG=GSRSv3.1.1PUB
    ARG EP_EXT_TAG=GSRSv3.1.1PUB
    #ARG MODULE_IGNORE="adverse-events applications clinical-trials impurities invitro-pharmacology products ssg4m"
    ARG MODULE_IGNORE=

    COPY patches /src/patches

    # Download Source and installExtraJars
    RUN git clone --recursive --depth=1 --branch ${GSRS_TAG} https://github.com/ncats/gsrs3-main-deployment.git && \
        cd gsrs3-main-deployment/substances && sh ./installExtraJars.sh && cd ../..

    # Install EP Extensions
    RUN [ -z "EP_EXT_TAG" ] && exit 0 ; \
        git clone --recursive --depth=1 --branch ${EP_EXT_TAG} https://github.com/epuzanov/gsrs-ep-substance-extension.git && \
        cd gsrs-ep-substance-extension && \
        sh ./mvnw clean -U install -DskipTests && \
        cd ..

    # Compile and deploy modules
    RUN cd gsrs3-main-deployment && \
        [ -z "EP_EXT_TAG" ] && rm -rf /src/patches/30-gsrsEpExtension.patch ; \
        apt-get update && apt-get install -y --no-install-recommends patch && [ -d /src/patches ] && find /src/patches -type f -name '*.patch' -print0 -exec patch -p1 -i {} \; ; \
        mkdir -p ${CATALINA_HOME}/conf/Catalina/localhost ${CATALINA_HOME}/webapps && \
        rm -rf ${MODULE_IGNORE} docs deployment-extras && \
        for module in `ls -1` ; do \
            [ ! -f ${module}/mvnw ] && continue ; \
            cd ${module} && \
            [ -f installExtraJars.sh ] && sh ./installExtraJars.sh ; \
            sh ./mvnw clean -U package -DskipTests && \
            unzip ./target/${module}.war.original -d ${CATALINA_HOME}/webapps/${module} && \
            mkdir -p ${CATALINA_HOME}/work/Catalina/localhost/${module} && \
            cd .. && \
            rm -rf ${module} ; done && \
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

FROM tomcat:9-jre11
    ENV CATALINA_HOME=/usr/local/tomcat
    ENV API_BASE_PATH=/ginas/app
    RUN rm -rf ${CATALINA_HOME}/temp && \
        /bin/echo -e "#!/bin/sh\nmkdir -p /home/srs/conf /home/srs/logs /home/srs/exports\ncd /home/srs\nexec \"\$@\"\n" > /entrypoint.sh && \
        chmod 755 /entrypoint.sh && \
        sed -i "s/logs/\/home\/srs\/logs/g" ${CATALINA_HOME}/conf/server.xml && \
        sed -i "s/8080/\$\{port.http.nossl:-8080\}/g" ${CATALINA_HOME}/conf/server.xml && \
        sed -i "s/connectionTimeout/maxPostSize=\"536870912\" relaxedQueryChars=\"\&#x5B;\&#x5D;\&#x7C;\&#x7B;\&#x7D;\&#x5E;\&#x5C;\&#x60;\&#x22;\&#x3C;\&#x3E;\" connectionTimeout/g" ${CATALINA_HOME}/conf/server.xml && \
        sed -i "s/unpackWARs=\"true\" autoDeploy=\"true\"/unpackWARs=\"false\" autoDeploy=\"false\" deployIgnore=\"\$\{deploy.ignore.pattern:-(adverse-events|applications|clinical-trials|impurities|invitro-pharmacology|products|ssg4m)\}\"/g" ${CATALINA_HOME}/conf/server.xml && \
        sed -i "s/\$.catalina.base././g" ${CATALINA_HOME}/conf/logging.properties && \
        mkdir -p /root/.cache/JNA /root/.java/fonts /home/srs/conf /home/srs/logs /home/srs/exports && \
        ln -s /tmp /root/.cache/JNA/temp && \
        ln -s /tmp /root/.java/fonts && \
        ln -s /tmp ${CATALINA_HOME}/temp
    COPY --from=build --chown=root ${CATALINA_HOME} ${CATALINA_HOME}
    WORKDIR /home/srs
    ENTRYPOINT [ "/entrypoint.sh" ]
    CMD ["catalina.sh", "run"]
