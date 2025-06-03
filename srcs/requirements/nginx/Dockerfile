FROM debian:bullseye

RUN apt update -y && apt install nginx openssl -y

ENV DOMAIN_NAME=irabhi.42.fr

RUN  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/ssl/private/nginx-selfsigned.key \
    -out /etc/ssl/certs/nginx-selfsigned.crt \
    -subj "/CN=$DOMAIN_NAME"

COPY config/nginx.conf /etc/nginx/nginx.conf

CMD ["nginx"]