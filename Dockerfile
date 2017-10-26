FROM ubuntu:latest

RUN apt-get update
RUN apt-get install -y vim wget apt-transport-https gnupg curl unzip git default-jdk maven

RUN apt-get install prosody -y
COPY jitsi.example.com.cfg.lua /etc/prosody/conf.avail/

RUN ln -s /etc/prosody/conf.avail/jitsi.example.com.cfg.lua /etc/prosody/conf.d/jitsi.example.com.cfg.lua
RUN ln -s /etc/prosody/certs/localhost.key /etc/prosody/certs/jitsi.example.com.key && \
		ln -s /etc/prosody/certs/localhost.crt /etc/prosody/certs/jitsi.example.com.cert

# INSTALL nginx
RUN apt-get install nginx -y

COPY jitsi.example.com /etc/nginx/sites-available
RUN cd /etc/nginx/sites-enabled && ln -s ../sites-available/jitsi.example.com jitsi.example.com

RUN mkdir $HOME/jitsi-videobridge
RUN cd $HOME/jitsi-videobridge
RUN wget https://download.jitsi.org/jitsi-videobridge/linux/jitsi-videobridge-linux-x86-1006.zip && \
		unzip jitsi-videobridge-linux-x86-1006.zip

RUN apt-get install -y default-jre

# RUN export org.jitsi.impl.neomedia.transform.srtp.SRTPCryptoContext.checkReplay false && \
# 		org.jitsi.impl.neomedia.transform.srtp.SRTPCryptoContext.checkReplay=false

ENV org.jitsi.impl.neomedia.transform.srtp.SRTPCryptoContext.checkReplay false

RUN ./jvb.sh --host=localhost --domain=jitsi.example.com --port=5347 --secret=YOURSECRET1 &

RUN mkdir $HOME/jicofo && cd $HOME/jicofo && \
		git clone https://github.com/jitsi/jicofo.git && \
		cd jicofo && \
		mvn package -DskipTests -Dassembly.skipAssembly=false && \
		unzip target/jicofo-linux-x64-1.1-SNAPSHOT.zip
RUN cd $HOME/jicofo/jicofo/jicofo-linux-x64-1.1-SNAPSHOT && \
		./jicofo.sh --host=localhost --domain=jitsi.example.com --secret=YOURSECRET2 --user_domain=auth.jitsi.example.com --user_name=focus --user_password=YOURSECRET3

RUN mkdir $HOME/jitsi-meet && cd $HOME/jitsi-meet && \
		git clone https://github.com/jitsi/jitsi-meet.git && \
		mv jitsi-meet/ $HOME/jitsi.example.com && \
		npm install && \
		make

COPY jitsi.domain.config $HOME/jitsi-meet/jitsi.example.com/
RUN echo $(cat $HOME/jitsi-meet/jitsi.example.com/jitsi.domain.config) >> $HOME/jitsi-meet/jitsi.example.com/config.js

RUN invoke-rc.d nginx restart
RUN echo "org.jitsi.videobridge.NAT_HARVESTER_LOCAL_ADDRESS=localhost:443" >> $HOME/.sip-communicator/sip-communicator.properties && \
		echo "org.jitsi.impl.neomedia.transform.srtp.SRTPCryptoContext.checkReplay=false" >> $HOME/.sip-communicator/sip-communicator.properties && \
		export public_ip $(curl -s ifconfig.co) && \
		echo "org.jitsi.videobridge.NAT_HARVESTER_LOCAL_ADDRESS=$public_ip" >> $HOME/.sip-communicator/sip-communicator.properties


RUN prosodyctl register focus auth.jitsi.example.com YOURSECRET3 & && \
		prosodyctl restart &

COPY run.sh run.sh
RUN "./run.sh"

