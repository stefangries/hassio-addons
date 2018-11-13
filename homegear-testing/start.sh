#/bin/bash

_term() {
	service homegear-influxdb stop
	service homegear stop
	exit $?
}

trap _term SIGTERM

echo LOS8

USER=homegear
USER_ID=$(id -u $USER)
USER_GID=$(id -g $USER)
USER_ID=${HOST_USER_ID:=$USER_ID}
USER_GID=${HOST_USER_GID:=$USER_GID}
sed -i -e "s/^${USER}:\([^:]*\):[0-9]*:[0-9]*/${USER}:\1:${USER_ID}:${USER_GID}/"  /etc/passwd
sed -i -e "s/^${USER}:\([^:]*\):[0-9]*/${USER}:\1:${USER_GID}/" /etc/group

mkdir -p /config/homegear /share/homegear/lib/homegear /share/homegear/log
chown homegear:homegear /config/homegear /share/homegear/log
rm -Rf /etc/homegear /var/log/homegear
ln -nfs /config/homegear     /etc/homegear
ln -nfs /share/homegear/log /var/log/homegear

if ! [ "$(ls -A /etc/homegear)" ]; then
	cp -a /etc/homegear.config/* /etc/homegear/
fi

if ! [ "$(ls -A /share/homegear/lib/homegear)" ]; then
	cp -a /var/lib/homegear/* /share/homegear/lib/homegear/
else
	rm -Rf /share/homegear/lib/homegear/modules/*
	rm -Rf /share/homegear/lib/homegear/flows/nodes/*
	cp -a /var/lib/homegear/modules/* /share/homegear/lib/homegear/modules/
	cp -a /var/lib/homegear/node-blue/nodes/* /share/homegear/lib/homegear/node-blue/nodes/
fi

if ! [ -f /var/log/homegear/homegear.log ]; then
	touch /var/log/homegear/homegear.log
fi

if ! [ -f /etc/homegear/dh1024.pem ]; then
	openssl genrsa -out /etc/homegear/homegear.key 2048
	openssl req -batch -new -key /etc/homegear/homegear.key -out /etc/homegear/homegear.csr
	openssl x509 -req -in /etc/homegear/homegear.csr -signkey /etc/homegear/homegear.key -out /etc/homegear/homegear.crt
	rm /etc/homegear/homegear.csr
	chmod 400 /etc/homegear/homegear.key
	openssl dhparam -check -text -5 -out /etc/homegear/dh1024.pem 1024
	chmod 400 /etc/homegear/dh1024.pem
fi

chown -R root:root /etc/homegear
find /etc/homegear -type d -exec chmod 755 {} \;
chown -R homegear:homegear /var/log/homegear /share/homegear/lib/homegear
find /var/log/homegear -type d -exec chmod 750 {} \;
find /var/log/homegear -type f -exec chmod 640 {} \;
find /share/homegear/lib/homegear -type d -exec chmod 750 {} \;
find /share/homegear/lib/homegear -type f -exec chmod 640 {} \;

ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

service homegear start
service homegear-management start
service homegear-influxdb start
tail -f /var/log/homegear/homegear.log &
child=$!
wait "$child"