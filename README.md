# gsrs3-docker
All-in-One Docker Image for GSRS3

# GSRS3

Global Substance Registration System assists agencies in 
registering and documenting information about substances 
found in medicines. It provides a 
common identifier for all of the substances 
used in medicinal products, utilizing a 
consistent definition of substances globally, 
including active substances under clinical 
investigation, consistent with the **ISO 11238** standard.

## How To Build and Run

### Build a docker image
Build All-in-One GSRS3 image:
```
docker build --ulimit nofile=65535:65535 -t gsrs3:latest
```

Build GSRS3 Image without "adverse-events", "applications", "clinical-trials" und "products" modules
```
docker build --ulimit nofile=65535:65535 --build-arg MODULE_IGNORE="adverse-events applications clinical-trials products" -t gsrs3:latest
```

### Database Initialization

#### H2
```
mkdir -p /var/lib/gsrs
docker run -ti --rm -v /var/lib/gsrs:/home -e DB_DDL_AUTO='create' gsrs3:latest
```

#### PostgreSQL
```
mkdir -p /var/lib/gsrs
docker run -ti --rm -v /var/lib/gsrs:/home -e DB_HOST='postgresql://db.server.org:5432/' -e DB_USERNAME='postgres' -e DB_PASSWORD='SecurePassword' -e DB_DDL_AUTO='create' gsrs3:latest
```

### Running the docker image
```
docker run -d -p 8080:8080 -v /var/lib/gsrs:/home -e JAVA_OPTS='-Xms12g -Xmx12g -XX:ReservedCodeCacheSize=512m' -e DB_HOST='postgresql://db.server.org:5432/' -e DB_USERNAME='postgres' -e DB_PASSWORD='SecurePassword' gsrs3:latest
```

### Running frontend and gateway only
```
docker run -d -p 8080:8080 -v /var/logs/gsrs:/home -e MS_URL_SUBSTANCES="http://gsrs3-substances.api.server.org:8080/substances" -e JAVA_OPTS='-Xms2g -Xmx2g -XX:ReservedCodeCacheSize=512m -Ddeploy.ignore.pattern="(adverse-events|applications|clinical-trials|impurities|products|substances)' --name gsrs3-frontend gsrs3:latest
```

### Running substances only
```
docker run -d -p 8080:8080 -v /var/lib/gsrs:/home -e JAVA_OPTS='-Xms12g -Xmx12g -XX:ReservedCodeCacheSize=512m -Dgateway.allow.pattern="\d+\.\d+\.\d+\.\d+" -Ddeploy.ignore.pattern="(adverse-events|applications|clinical-trials|frontend|ROOT|impurities|products)' -e DB_HOST='postgresql://db.server.org:5432/' -e DB_USERNAME='postgres' -e DB_PASSWORD='SecurePassword' --name gsrs3-substances gsrs3:latest
```

### Custom configuration files (optional)
The custom configuration files can be plased in the "conf" subdirectory in the working directory.

The custom configuration file for the "substances" module: /home/conf/substances.conf

The custom configuration file for the "gateway" module: /home/conf/gateway.conf

### Environment Varables
- API_URL (http://localhost:8080/)
- APPLICATION_HOST (http://localhost:8080)
- APPROVALID_GENERATOR (ix.ginas.utils.UNIIGenerator)
- APPROVALID_NAME
- APPROVALID_CODESYSTEM
- AUTH_ALLOW_NONAUTH (true)
- AUTH_EMAIL_HEADER (AUTHENTICATION_HEADER_NAME_EMAIL)
- AUTH_ROLES_HEADER
- AUTH_SYSADMIN_EMAIL
- AUTH_TRUST_HEADER (true)
- AUTH_USERNAME_HEADER (OAM_REMOTE_USER)
- DB_DDL_AUTO (none)
- DB_DIALECT
- DB_HOST
- DB_NAME_ADVERSE_EVENTS (adverseevents)
- DB_NAME_APPLICATIONS (applications)
- DB_NAME_CLINICAL_TRIALS (clinicaltrials)
- DB_NAME_IMPURITIES (impurities)
- DB_NAME_PRODUCTS (products)
- DB_NAME_SUBSTANCES (substances)
- DB_PASSWORD
- DB_USERNAME
- DB_URL_ADVERSE_EVENTS (jdbc:h2:"${ix.h2.base}"/appinxight;MODE=Oracle;AUTO_SERVER=TRUE)
- DB_URL_APPLICATIONS (jdbc:h2:"${ix.h2.base}"/appinxight;MODE=Oracle;AUTO_SERVER=TRUE)
- DB_URL_CLINICAL_TRIALS (jdbc:h2:"${ix.h2.base}"/appinxight;MODE=Oracle;AUTO_SERVER=TRUE)
- DB_URL_IMPURITIES (jdbc:h2:"${ix.h2.base}"/appinxight;MODE=Oracle;AUTO_SERVER=TRUE)
- DB_URL_PRODUCTS (jdbc:h2:"${ix.h2.base}"/appinxight;MODE=Oracle;AUTO_SERVER=TRUE)
- DB_URL_SUBSTANCES (jdbc:h2:"${ix.h2.base}"/appinxight;MODE=Oracle;AUTO_SERVER=TRUE)
- DB_USE_NEW_ID_GENERATOR_MAPPINGS (true)
- EUREKA_CLIENT_ENABLED (false)
- EUREKA_SERVICE_URL (http://localhost:8761/eureka)
- FRONTEND_ROUTE_PREFIX (ginas/app/beta)
- FRONTEND_CONFIG_DIR (classpath:/static/assets/data)
- MS_URL_ADVERSE_EVENTS (http://localhost:8080/adverse-events)
- MS_URL_APPLICATIONS (http://localhost:8080/applications)
- MS_URL_CLINICAL_TRIALS (http://localhost:8080/clinical-trials)
- MS_URL_CLINICAL_TRIALS_EUROPE (http://localhost:8080/clinical-trials)
- MS_URL_CLINICAL_TRIALS_US (http://localhost:8080/clinical-trials)
- MS_URL_FRONTEND (http://localhost:8080/frontend)
- MS_URL_IMPURITIES (http://localhost:8080/impurities)
- MS_URL_PRODUCTS (http://localhost:8080/products)
- MS_URL_SUBSTANCES (http://localhost:8080/substances)
- CATALINA_OPTS (-Dlog.level="info" -Ddeploy.ignore.pattern="(adverse-events|applications|clinical-trials|impurities|products)")

