FROM nginx:1.27-alpine

RUN apk add --no-cache openssl

COPY --chmod=755 nginx/50-generate-selfsigned-cert.sh /docker-entrypoint.d/50-generate-selfsigned-cert.sh
COPY nginx/nginx.conf /etc/nginx/nginx.conf
