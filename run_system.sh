#!/bin/bash

$YOURSECRET1="secret1"
$YOURSECRET2="secret2"
$YOURSECRET3="secret3"

apt-get update
apt-get install -y vim wget apt-transport-https gnupg curl unzip git default-jdk maven prosody default-jre

cp jitsi.example.com.cfg.lua /etc/prosody/conf.avail/

ln -s /etc/prosody/conf.avail/jitsi.example.com.cfg.lua /etc/prosody/conf.d/jitsi.example.com.cfg.lua
ln -s /etc/prosody/certs/localhost.key /etc/prosody/certs/jitsi.example.com.key
ln -s /etc/prosody/certs/localhost.crt /etc/prosody/certs/jitsi.example.com.cert

# INSTALL nginx
apt-get install nginx -y

cp jitsi.example.com /etc/nginx/sites-available
cd /etc/nginx/sites-enabled && ln -s ../sites-available/jitsi.example.com jitsi.example.com

mkdir $HOME/jitsi
mkdir $HOME/jitsi/jitsi-videobridge
cd $HOME/jitsi/jitsi-videobridge
wget https://download.jitsi.org/jitsi-videobridge/linux/jitsi-videobridge-linux-x86-1006.zip
unzip jitsi-videobridge-linux-x86-1006.zip

# export org.jitsi.impl.neomedia.transform.srtp.SRTPCryptoContext.checkReplay false && \
# 		org.jitsi.impl.neomedia.transform.srtp.SRTPCryptoContext.checkReplay=false

export org.jitsi.impl.neomedia.transform.srtp.SRTPCryptoContext.checkReplay false

./jvb.sh --host=localhost --domain=jitsi.example.com --port=5347 --secret=$YOURSECRET1 &

mkdir $HOME/jitsi/jicofo && cd $HOME/jitsi/jicofo && \
	git clone https://github.com/jitsi/jicofo.git && \
	cd jicofo && \
	mvn package -DskipTests -Dassembly.skipAssembly=false && \
	unzip target/jicofo-linux-x64-1.1-SNAPSHOT.zip

cd $HOME/jitsi/jicofo/jicofo/jicofo-linux-x64-1.1-SNAPSHOT && \
	./jicofo.sh --host=localhost --domain=jitsi.example.com --secret=$YOURSECRET2 --user_domain=auth.jitsi.example.com --user_name=focus --user_password=$YOURSECRET3

mkdir $HOME/jitsi/jitsi-meet && cd $HOME/jitsi/jitsi-meet && \
	git clone https://github.com/jitsi/jitsi-meet.git && \
	mv jitsi-meet/ $HOME/jitsi/jitsi.example.com && \
	npm install && \
	make

cp jitsi.domain.config $HOME/jitsi/jitsi-meet/jitsi.example.com/
echo $(cat $HOME/jitsi/jitsi-meet/jitsi.example.com/jitsi.domain.config) >> $HOME/jitsi/jitsi-meet/jitsi.example.com/config.js

invoke-rc.d nginx restart
echo "org.jitsi.videobridge.NAT_HARVESTER_LOCAL_ADDRESS=localhost:443" >> $HOME/jitsi/.sip-communicator/sip-communicator.properties && \
	echo "org.jitsi.impl.neomedia.transform.srtp.SRTPCryptoContext.checkReplay=false" >> $HOME/jitsi/.sip-communicator/sip-communicator.properties && \
	export public_ip $(curl -s ifconfig.co) && \
	echo "org.jitsi.videobridge.NAT_HARVESTER_LOCAL_ADDRESS=$public_ip" >> $HOME/jitsi/.sip-communicator/sip-communicator.properties


prosodyctl register focus auth.jitsi.example.com $YOURSECRET3 & && \
	prosodyctl restart &
