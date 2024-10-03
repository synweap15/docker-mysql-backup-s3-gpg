FROM mysql:5.7.39-debian

ENV AWS_ACCESS_KEY_ID="" \
    AWS_SECRET_ACCESS_KEY="" \
    AWS_DEFAULT_REGION="us-east-1" \
    AWS_ENDPOINT="" \
    BACKUP_SCHEDULE="0 0 * * *" \
    BACKUP_BUCKET="backup" \
    BACKUP_PREFIX="mysql/%Y/%m/%d/mysql-" \
    BACKUP_SUFFIX="-%Y%m%d-%H%M.sql.gpg" \
    PGP_KEY="" \
    PGP_KEYSERVER="hkps://keys.gnupg.net,hkps://pgp.mit.edu,hkps://keyserver.ubuntu.com,hkps://peegeepee.com,hkp://keys.gnupg.net,hkp://pgp.mit.edu,hkp://keyserver.ubuntu.com,hkp://pool.sks-keyservers.net" \
    SENDGRID_API_KEY="" \
    MAIL_FROM="" \
    MAIL_TO=""

#   MYSQL_HOST MYSQL_ROOT_PASSWORD MYSQL_USER MYSQL_PASSWORD MYSQL_DATABASE MYSQLDUMP_ADDITIONAL_OPTS

RUN gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys B7B3B788A8D3785C \
    && rm /etc/apt/keyrings/mysql.gpg \
    && gpg  --output /etc/apt/keyrings/mysql.gpg --export B7B3B788A8D3785C \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
           python3 python3-pip python3-setuptools python3-wheel \
           cron wget curl \
    && pip3 install awscli \
    && apt-get clean autoclean \
    && apt-get autoremove --yes \
    && rm -rf /var/lib/{apt,dpkg,cache,log}/ \
    && echo "Done."

COPY README.md /
COPY *.sh /usr/local/bin/

ENTRYPOINT ["docker-entrypoint.sh"]

CMD ["cron"]
