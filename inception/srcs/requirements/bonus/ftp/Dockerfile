FROM debian:bullseye

RUN apt update -y && apt upgrade -y && apt install -y vsftpd 

COPY tools/ftp.sh /ftp.sh

RUN chmod +x /ftp.sh

CMD ["/ftp.sh"]

# RUN mkdir -p /var/run/vsftpd/empty && chmod 755 /var/run/vsftpd/empty && mkdir -p /var/www/html

# RUN useradd -m ftpuser && echo "ftpuser:$FTP_PASSWORD" | chpasswd && chown -R ftpuser:ftpuser /var/www/html

# COPY conf/vsftpd.conf /etc/vsftpd.conf

# EXPOSE 21 21000-21010

# CMD ["/usr/sbin/vsftpd", "/etc/vsftpd.conf"]