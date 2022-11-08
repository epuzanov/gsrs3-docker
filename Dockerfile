FROM maven:3-jdk-11 as build
    ENV MAVEN_CONFIG=
    ENV CATALINA_HOME=/usr/local/tomcat
    ARG GSRS_VER=3.0.3-SNAPSHOT
    ARG GSRS_TAG=main
    #ARG MODULE_IGNORE="adverse-events applications clinical-trials products"
    ARG MODULE_IGNORE=

    COPY patches /patches
    RUN apt-get update && apt-get install -y --no-install-recommends patch
    RUN git clone https://github.com/ncats/gsrs-spring-starter.git && \
        cd gsrs-spring-starter && \
        ./installExtraJars.sh && \
        ./mvnw clean -U install -DskipTests && \
        cd ..
    RUN git clone https://github.com/ncats/gsrs-spring-module-substances.git && \
        cd gsrs-spring-module-substances && \
        ./installExtraJars.sh && \
        ./mvnw clean -U install -DskipTests && \
        cd ..
    RUN git clone https://github.com/ncats/gsrs-spring-module-adverse-events.git && \
        cd gsrs-spring-module-adverse-events && \
        sed -i "s/Hoxton.SR1/2020.0.2/g" pom.xml && \
        sed -i "s/2.17.1/2.17.2/g" pom.xml && \
        sh ./mvnw clean -U install -DskipTests && \
        cd ..
    RUN git clone https://github.com/ncats/gsrs-spring-module-drug-applications.git && \
        cd gsrs-spring-module-drug-applications && \
        sed -i "s/Hoxton.SR1/2020.0.2/g" pom.xml && \
        sed -i "s/2.17.1/2.17.2/g" pom.xml && \
        sh ./mvnw clean -U install -DskipTests && \
        cd ..
    RUN git clone https://github.com/ncats/gsrs-spring-module-clinical-trials.git && \
        cd gsrs-spring-module-clinical-trials && \
        sed -i "s/Hoxton.SR1/2020.0.2/g" pom.xml && \
        sed -i "s/2.17.1/2.17.2/g" pom.xml && \
        sh ./mvnw clean -U install -DskipTests && \
        cd ..
    RUN git clone https://github.com/ncats/gsrs-spring-module-impurities.git && \
        cd gsrs-spring-module-impurities && \
        sed -i "s/Hoxton.SR1/2020.0.2/g" pom.xml && \
        sed -i "s/2.17.1/2.17.2/g" pom.xml && \
        sh ./mvnw clean -U install -DskipTests && \
        cd ..
    RUN git clone https://github.com/ncats/gsrs-spring-module-drug-products.git && \
        cd gsrs-spring-module-drug-products && \
        sed -i "s/Hoxton.SR1/2020.0.2/g" pom.xml && \
        sed -i "s/2.17.1/2.17.2/g" pom.xml && \
        sh ./mvnw clean -U install -DskipTests && \
        cd ..
    RUN git clone --recursive --depth=1 --branch STAGE https://github.com/ncats/gsrs3-main-deployment.git && \
        cd gsrs3-main-deployment && \
        find /patches -type f -name '*.patch' -print0 -exec patch -p1 -i {} \; && \
        mkdir -p ${CATALINA_HOME}/conf/Catalina/localhost ${CATALINA_HOME}/webapps && \
        rm -rf ${MODULE_IGNORE} && \
        for module in `ls -1` ; do \
            [ ! -f ${module}/mvnw ] && continue ; \
            cd ${module} && \
            chmod 755 mvnw && \
            ./mvnw clean -U package -DskipTests && \
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
    RUN git clone https://github.com/epuzanov/gsrs-ep-substance-extension.git  && \
        cd gsrs-ep-substance-extension && \
        [ -d ${CATALINA_HOME}/webapps/substances ] && ./mvnw clean -U package -DskipTests ; \
        [ -f "./target/gsrs-ep-substance-extension-${GSRS_VER}.jar" ] && cp ./target/gsrs-ep-substance-extension-${GSRS_VER}.jar ${CATALINA_HOME}/webapps/substances/WEB-INF/lib/ ; \
        [ -f /root/.m2/repository/io/burt/jmespath-core/0.5.1/jmespath-core-0.5.1.jar ] && cp /root/.m2/repository/io/burt/jmespath-core/0.5.1/jmespath-core-0.5.1.jar ${CATALINA_HOME}/webapps/substances/WEB-INF/lib/ ; \
        [ -f /root/.m2/repository/io/burt/jmespath-jackson/0.5.1/jmespath-jackson-0.5.1.jar ] && cp /root/.m2/repository/io/burt/jmespath-jackson/0.5.1/jmespath-jackson-0.5.1.jar ${CATALINA_HOME}/webapps/substances/WEB-INF/lib/ ; \
        [ -f /root/.m2/repository/org/apache/cxf/cxf-core/3.5.3/cxf-core-3.5.3.jar ] && cp /root/.m2/repository/org/apache/cxf/cxf-core/3.5.3/cxf-core-3.5.3.jar ${CATALINA_HOME}/webapps/substances/WEB-INF/lib/ ; \
        [ -f /root/.m2/repository/org/apache/cxf/cxf-rt-rs-json-basic/3.5.3/cxf-rt-rs-json-basic-3.5.3.jar ] && cp /root/.m2/repository/org/apache/cxf/cxf-rt-rs-json-basic/3.5.3/cxf-rt-rs-json-basic-3.5.3.jar ${CATALINA_HOME}/webapps/substances/WEB-INF/lib/ ; \
        [ -f /root/.m2/repository/org/apache/cxf/cxf-rt-rs-security-jose/3.5.3/cxf-rt-rs-security-jose-3.5.3.jar ] && cp /root/.m2/repository/org/apache/cxf/cxf-rt-rs-security-jose/3.5.3/cxf-rt-rs-security-jose-3.5.3.jar ${CATALINA_HOME}/webapps/substances/WEB-INF/lib/ ; \
        [ -f /root/.m2/repository/org/apache/cxf/cxf-rt-security/3.5.3/cxf-rt-security-3.5.3.jar ] && cp /root/.m2/repository/org/apache/cxf/cxf-rt-security/3.5.3/cxf-rt-security-3.5.3.jar ${CATALINA_HOME}/webapps/substances/WEB-INF/lib/ ; \
        cd ..

FROM tomcat:9-jre11
    ENV CATALINA_HOME=/usr/local/tomcat
    RUN rm -rf ${CATALINA_HOME}/temp && \
        sed -i "s/logs/\/home\/logs/g" ${CATALINA_HOME}/conf/server.xml && \
        sed -i "s/connectionTimeout/maxPostSize=\"536870912\" connectionTimeout/g" ${CATALINA_HOME}/conf/server.xml && \
        sed -i "s/unpackWARs=\"true\" autoDeploy=\"true\"/unpackWARs=\"false\" autoDeploy=\"false\" deployIgnore=\"\$\{deploy.ignore.pattern:-(adverse-events|applications|clinical-trials|impurities|products)\}\"/g" ${CATALINA_HOME}/conf/server.xml && \
        sed -i "s/\$.catalina.base././g" ${CATALINA_HOME}/conf/logging.properties && \
        mkdir -p /root/.cache/JNA /root/.java/fonts && \
        ln -s /tmp /root/.cache/JNA/temp && \
        ln -s /tmp /root/.java/fonts && \
        ln -s /tmp ${CATALINA_HOME}/temp
    COPY --from=build --chown=root ${CATALINA_HOME} ${CATALINA_HOME}
    VOLUME ["/home"]
    WORKDIR /home
