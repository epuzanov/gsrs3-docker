FROM maven:3-jdk-11 as build
    ENV MAVEN_CONFIG=
    ENV CATALINA_HOME=/usr/local/tomcat
    ARG GSRS_TAG=master
    ARG GSRS_REPO=gsrs3-main-deployment
    ARG GSRS_URL=http://github.com/ncats
    ARG LOCAL_REPOS=/local
    #ARG IGNORE_MODULES="adverse-events applications clinical-trials impurities invitro-pharmacology products ssg4m"
    ARG IGNORE_MODULES=
    ARG FRONTEND_BUILD_ARGS=
    ARG STARTER_MODULES=" \
        gsrs-spring-starter:master \
        gsrs-spring-module-substances:master \
        gsrs-spring-module-adverse-events:starter \
        gsrs-spring-module-drug-applications:starter \
        gsrs-spring-module-clinical-trials:master \
        gsrs-spring-module-impurities:starter \
        gsrs-spring-module-invitro-pharmacology:master \
        gsrs-spring-module-drug-products:starter \
        gsrs-spring-module-ssg4:master \
    "

    COPY . /src/${GSRS_REPO}

    # Download and prepare Source
    RUN [ -d /src/${GSRS_REPO}${LOCAL_REPOS} ] && mv /src/${GSRS_REPO}${LOCAL_REPOS} /src${LOCAL_REPOS} ; \
        [ -d /src/${GSRS_REPO}/patches ] && mv /src/${GSRS_REPO}/patches /src/patches ; \
        [ ! -d /src/${GSRS_REPO}/substances ] && rm -rf /src/${GSRS_REPO} ; \
        [ ! -d /src/${GSRS_REPO} ] && \
        git clone --recursive --depth=1 --branch ${GSRS_TAG} ${GSRS_URL}/${GSRS_REPO}.git /src/${GSRS_REPO} ; \
        cd /src/${GSRS_REPO} && \
        for module in `ls -1` ; do \
            [ ! -d ${module} ] && continue ; \
            echo "./mvnw clean -U package \\" > ${module}/build.sh && \
            chmod 755 ${module}/build.sh ; done && \
        [ -z "${FRONTEND_BUILD_ARGS}" ] && [ "master" = "${GSRS_TAG}" ] && echo "-Dfrontend.tag=development_3.0 -Dwithout.visualizer \\" >> frontend/build.sh ; \
        [ -z "${FRONTEND_BUILD_ARGS}" ] && [ ! "master" = "${GSRS_TAG}" ] && echo "-Dfrontend.tag=${GSRS_TAG} -Dwithout.visualizer \\" >> frontend/build.sh ; \
        [ ! -z "${FRONTEND_BUILD_ARGS}" ] && echo "${FRONTEND_BUILD_ARGS} \\" >> frontend/build.sh ; \
        [ -d /src${LOCAL_REPOS}/frontend-bin ] && echo "-Dnode.disable -Dfrontend.repo=file:///src${LOCAL_REPOS}/frontend-bin" >> frontend/build.sh ; \
        echo "-DskipTests" >> frontend/build.sh && \
        cd substances && \
        sh ./installExtraJars.sh && \
        ./mvnw dependency:resolve && exit 0 ; \
        mkdir -p /src${LOCAL_REPOS} && \
        cd /src${LOCAL_REPOS} && \
        for repo in ${STARTER_MODULES} ; do \
            [ ! -d ${repo%:*} ] && git clone --recursive --depth=1 --branch ${repo#*:} ${GSRS_URL}/${repo%:*}.git ; \
            [ -d ${repo%:*} ] && echo "./mvnw clean -U package -DskipTests \\" > ${repo%:*}/build.sh ; \
            [ -d ${repo%:*} ] && chmod 755 ${repo%:*}/build.sh ; \
        done && cd ..

    # Build starter modules from source if needed
    RUN [ ! -d /src${LOCAL_REPOS} ] && exit 0 ; \
        cd /src${LOCAL_REPOS} && \
        for repo in ${STARTER_MODULES} ; do \
            cd ${repo%:*} && \
            [ -f installExtraJars.sh ] && sh ./installExtraJars.sh ; \
            sh ./mvnw clean -U install -DskipTests && cd .. ; \
        done && cd ..

    # Apply patches if needed
    RUN [ ! -d /src/patches ] && exit 0 ; \
        cd /src/${GSRS_REPO} && \
        apt-get update && apt-get install -y --no-install-recommends patch && \
        find /src/patches -type f -name '*.patch' -print0 -exec patch -p1 -i {} \;

    # Compile and deploy modules
    RUN cd /src/${GSRS_REPO} && \
        mkdir -p ${CATALINA_HOME}/conf/Catalina/localhost ${CATALINA_HOME}/webapps && \
        rm -rf ${IGNORE_MODULES} docs deployment-extras && \
        for module in `ls -1` ; do \
            [ ! -f ${module}/mvnw ] && continue ; \
            cd ${module} && \
            [ -f installExtraJars.sh ] && sh ./installExtraJars.sh ; \
            sh ./build.sh && \
            unzip ./target/${module}.war.original -d ${CATALINA_HOME}/webapps/${module} && \
            mkdir -p ${CATALINA_HOME}/work/Catalina/localhost/${module} && \
            cd .. && \
            rm -rf ${module} ; \
        done && \
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
