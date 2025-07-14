#!/bin/bash

mkdir -p /var/run/vsftpd/empty && chmod 755 /var/run/vsftpd/empty && mkdir -p /var/www/html

useradd -m ftpuser && echo "ftpuser:$FTP_PASSWORD" | chpasswd && chown -R ftpuser:ftpuser /var/www/html

/usr/sbin/vsftpd /etc/vsftpd.conf