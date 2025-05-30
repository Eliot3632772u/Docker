FROM debian:bullseye

RUN apt update -y && apt upgrade -y && \
    apt install -y mariadb-server

COPY conf/50-server.conf /etc/mysql/mariadb.conf.d/50-server.cnf
COPY tools/mariadb.sh /usr/local/bin/mariadb.sh

RUN chmod +x /usr/local/bin/mariadb.sh

CMD ["mariadb"]