FROM nginx:1.27-alpine

RUN apk add --no-cache openssl \
  && mkdir -p /etc/nginx/certs \
  && openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
    -keyout /etc/nginx/certs/selfsigned.key \
    -out /etc/nginx/certs/selfsigned.crt \
    -subj "/C=AR/ST=BuenosAires/L=BuenosAires/O=Telecom/OU=Infra/CN=localhost"

COPY nginx/40-generate-basic-auth.sh /docker-entrypoint.d/40-generate-basic-auth.sh
COPY nginx/nginx.conf /etc/nginx/nginx.conf

RUN chmod +x /docker-entrypoint.d/40-generate-basic-auth.sh
