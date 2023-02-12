# build missing perl dependencies for use in final container
FROM ubuntu:22.04 as builder

ENV TZ America/Chicago
WORKDIR /usr/src

# Install python requirements for zmeventserver
COPY requirements.txt /usr/src/requirements.txt

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
        python3 \
        python3-pip \
        python3-dev \
    && apt-get clean

RUN apt-file update \
    && dh-make-perl --build --cpan Net::WebSocket::Server \
    && dh-make-perl --build --cpan Net::MQTT::Simple \
    && pip3 install --no-cache-dir -r /usr/src/requirements.txt \
    && find /usr/lib/ -name '__pycache__' -print0 | xargs -0 -n1 rm -rf \
	&& find /usr/lib/ -name '*.pyc' -print0 | xargs -0 -n1 rm -rf \
    && ls /usr/lib -l

# Now build the final image
FROM ubuntu:22.04
LABEL maintainer="Silvertoken"

ENV TZ America/Chicago
ENV ZM_DB_HOST db
ENV ZM_DB_NAME zm 
ENV ZM_DB_USER zmuser
ENV ZM_DB_PASS zmpass
ENV ZM_DB_PORT 3306

COPY --from=builder /usr/src/*.deb /usr/src/

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
        gcc \
        # Perl modules needed for zmeventserver
        libyaml-perl \
        libjson-perl \
        libconfig-inifiles-perl \
        liblwp-protocol-https-perl \
        libprotocol-websocket-perl \
        # Other dependencies for event zmeventserver
        python3 \
        libgeos-dev \
        gifsicle \
	    gnupg \
	    wget \
    && dpkg -i /usr/src/*.deb \
    && apt-get clean \
    && rm -rf /tmp/* /var/tmp/*  \
    && rm -rf /var/lib/apt/lists/* \
    &&  mkdir -p /etc/service/apache2 /var/log/apache2 /var/log/zm /etc/my_init.d \
    && ls /usr/lib -l

# Copy the zoneminder dependecies from builder
COPY --from=builder /usr/lib/python3.10/site-packages/ /usr/lib/python3.10/site-packages/

# Install zoneminder
RUN echo "deb http://ppa.launchpad.net/iconnor/zoneminder-1.36/ubuntu `cat /etc/os-release | grep UBUNTU_CODENAME | cut -d = -f 2` main" >> /etc/apt/sources.list  \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 776FFB04 \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends php-gd libapache2-mod-php7.4 zoneminder \
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
ENV ZMEVENT_VERSION v6.1.27
RUN mkdir /usr/src/zmevent \
    && cd /usr/src/zmevent \
    && wget -qO- https://github.com/pliablepixels/zmeventnotification/archive/${ZMEVENT_VERSION}.tar.gz |tar -xzv --strip 1 \
    && ./install.sh --install-config --install-es --install-hook --no-interactive --no-pysudo \
    && rm -R /usr/src/zmevent

# copying scripts
COPY *.sh /usr/src/
COPY etc/* /etc/zm/

# Moving scripts to correct locations and setting permissions
RUN mv /usr/src/apache2.sh /etc/service/apache2/run \
    && mv /usr/src/zm.sh /sbin/zm.sh \
    && mv /usr/src/startup.sh /etc/my_init.d/startup.sh \
    && chmod +x /etc/service/apache2/run \
    && chown -R www-data /var/log/apache2 \
    && chmod +x /sbin/zm.sh \
    && chmod +x /etc/my_init.d/startup.sh

VOLUME /var/cache/zoneminder /etc/zm /var/log/zm /var/lib/zmeventnotification/models /var/lib/zmeventnotification/images
# to allow access from outside of the container  to the container service
# at that ports need to allow access from firewall if need to access it outside of the server. 
EXPOSE 80 9000 6802

# Use the startup script
CMD ["/etc/my_init.d/startup.sh"]
