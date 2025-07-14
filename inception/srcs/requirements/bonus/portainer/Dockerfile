FROM debian:bullseye

RUN apt update && apt upgrade -y && apt install curl -y

RUN curl -L "https://github.com/portainer/portainer/releases/download/2.19.1/portainer-2.19.1-linux-amd64.tar.gz" -o portainer.tar.gz 

RUN tar -xpf portainer.tar.gz

RUN mkdir /data

CMD ["/portainer/portainer"]