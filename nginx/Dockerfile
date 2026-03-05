FROM nginx:1.27-alpine

RUN apk add --no-cache openssl

COPY nginx/50-generate-selfsigned-cert.sh /docker-entrypoint.d/50-generate-selfsigned-cert.sh
COPY nginx/nginx.conf /etc/nginx/nginx.conf

RUN chmod +x /docker-entrypoint.d/50-generate-selfsigned-cert.sh
