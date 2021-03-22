# build missing perl dependencies for use in final container
FROM ubuntu:20.04 as perlbuild

ENV TZ America/New_York
WORKDIR /usr/src
RUN echo $TZ > /etc/timezone && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends \
        perl \
        make \	
        gcc \
        net-tools \
        build-essential \
        dh-make-perl \
        libgit-repository-perl \
        libprotocol-websocket-perl \
        apt-file \
    && apt-get clean
RUN apt-file update \
    && dh-make-perl --build --cpan Net::WebSocket::Server \
    && dh-make-perl --build --cpan Net::MQTT::Simple

# Now build the final image
FROM quantumobject/docker-baseimage:20.04
LABEL maintainer="Angel Rodriguez <angel@quantumobject.com>"

ENV TZ America/New_York
ENV ZM_DB_HOST db
ENV ZM_DB_NAME zm 
ENV ZM_DB_USER zmuser
ENV ZM_DB_PASS zmpass
ENV ZM_DB_PORT 3306

COPY --from=perlbuild /usr/src/*.deb /usr/src/

# Update the container
# Installation of nesesary package/software for this containers...
RUN echo $TZ > /etc/timezone && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends \
        libvlc-dev  \
        libvlccore-dev\
        apache2 \
        libapache2-mod-perl2 \
        vlc \
        ntp \
        dialog \
        ntpdate \
        ffmpeg \
        ssmtp \
        # Perl modules needed for zmeventserver
        libyaml-perl \
        libjson-perl \
        libconfig-inifiles-perl \
        liblwp-protocol-https-perl \
        libprotocol-websocket-perl \
        # Other dependencies for event zmeventserver
        python3-pip \
        libgeos-dev \
        gifsicle \
    && dpkg -i /usr/src/*.deb \
    && apt-get clean \
    && rm -rf /tmp/* /var/tmp/*  \
    && rm -rf /var/lib/apt/lists/* \
    &&  mkdir -p /etc/service/apache2 /var/log/apache2 /var/log/zm /etc/my_init.d

# copying scripts
COPY *.sh /usr/src/

# Moving scripts to correct locations and setting permissions
RUN mv /usr/src/apache2.sh /etc/service/apache2/run \
    && mv /usr/src/zm.sh /sbin/zm.sh \
    && mv /usr/src/startup.sh /etc/my_init.d/startup.sh \
    && chmod +x /etc/service/apache2/run \
    && cp /var/log/cron/config /var/log/apache2/ \
    && chown -R www-data /var/log/apache2 \
    && chmod +x /sbin/zm.sh \
    && chmod +x /etc/my_init.d/startup.sh

# Install python requirements for zmeventserver
COPY requirements.txt /usr/src/requirements.txt

RUN pip3 install --no-cache-dir -r /usr/src/requirements.txt

# Install zoneminder
RUN echo "deb http://ppa.launchpad.net/iconnor/zoneminder-1.34/ubuntu `cat /etc/container_environment/DISTRIB_CODENAME` main" >> /etc/apt/sources.list  \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 776FFB04 \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends php-gd zoneminder \
    && echo "ServerName localhost" | tee /etc/apache2/conf-available/fqdn.conf \
    && ln -s /etc/apache2/conf-available/fqdn.conf /etc/apache2/conf-enabled/fqdn.conf \
    && a2enmod cgi rewrite \
    && a2enconf zoneminder \
    && chown -R www-data:www-data /usr/share/zoneminder/ \
    && adduser www-data video \
    && mkdir -p /etc/backup_zm_conf \
    && cp -R /etc/zm/* /etc/backup_zm_conf/ \
    && rm -R /var/www/html \
    && rm /etc/apache2/sites-enabled/000-default.conf \
    && apt-get clean \
    && rm -rf /tmp/* /var/tmp/* \
    && rm -rf /var/lib/apt/lists/*

#install zmeventserver
ENV ZMEVENT_VERSION 6.1.15
RUN cd /usr/src/ \
    && wget -qO- https://github.com/pliablepixels/zmeventnotification/archive/v${ZMEVENT_VERSION}.tar.gz |tar -xzv \
    && cd /usr/src/zmeventnotification-${ZMEVENT_VERSION} \
    && ./install.sh --install-config --install-es --install-hook --no-interactive --no-download-models --no-pysudo \
    && rm -R /usr/src/zmeventnotification-${ZMEVENT_VERSION}

VOLUME /var/cache/zoneminder /etc/zm /config /var/log/zm /var/lib/zmeventnotification/models /var/lib/zmeventnotification/images
# to allow access from outside of the container  to the container service
# at that ports need to allow access from firewall if need to access it outside of the server. 
EXPOSE 80 9000 6802

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]
