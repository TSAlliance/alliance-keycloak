FROM quay.io/keycloak/keycloak:latest as builder

ENV KC_METRICS_ENABLED=true
ENV KC_FEATURES=token-exchange
ENV KC_DB=mysql
RUN /opt/keycloak/bin/kc.sh build

FROM quay.io/keycloak/keycloak:latest
COPY --from=builder /opt/keycloak/lib/quarkus/ /opt/keycloak/lib/quarkus/
WORKDIR /opt/keycloak

# for demonstration purposes only, please make sure to use proper certificates in production instead
ENV KEYCLOAK_ADMIN=root
ENV KEYCLOAK_ADMIN_PASSWORD=

# MySQL URL settings
ENV KC_DB_URL_HOST=172.17.0.1:3306
ENV KC_DB_URL_DATABASE=keycloak
ENV KC_DB_URL_PROPERTIES=?characterEncoding=UTF-8

# MySQL User settings
ENV KC_DB_USERNAME=keycloak
ENV KC_DB_PASSWORD=

# HTTP settings
RUN mkdir /opt/keycloak/cert/
COPY cert/fullchain.pem /opt/keycloak/cert/fullchain.pem
COPY cert/privkey.pem /opt/keycloak/cert/privkey.pem

ENV KC_HTTPS_CERTIFICATE_FILE=cert/fullchain.pem
ENV KC_HTTPS_CERTIFICATE_KEY_FILE=cert/privkey.pem

# Port settings
ENV KC_HTTPS_PORT=8888
ENV KC_HTTP_PORT=8887
ENV KC_HTTP_ENABLED=false

# Proxy
ENV KC_PROXY=edge

# Hostname config
ENV KC_HOSTNAME=
ENV KC_HOSTNAME_STRICT=false

ENTRYPOINT ["/opt/keycloak/bin/kc.sh", "start"]