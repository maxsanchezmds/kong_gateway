ARG KONG_BASE_IMAGE=kong:3.7
FROM ${KONG_BASE_IMAGE}

USER root
WORKDIR /opt/kong-gateway

COPY kong.yml.template ./kong.yml.template
COPY entrypoint.sh ./entrypoint.sh

RUN chmod 0555 ./entrypoint.sh \
 && chown -R kong:0 /opt/kong-gateway \
 && chmod -R g=u /opt/kong-gateway

USER kong

ENV KONG_DATABASE=off \
    KONG_DECLARATIVE_CONFIG=/tmp/kong.generated.yml \
    KONG_PROXY_LISTEN=0.0.0.0:8000 reuseport backlog=16384 \
    KONG_ADMIN_LISTEN=off \
    KONG_STATUS_LISTEN=off \
    KONG_NGINX_WORKER_PROCESSES=auto

ENTRYPOINT ["/opt/kong-gateway/entrypoint.sh"]
CMD ["kong", "docker-start"]