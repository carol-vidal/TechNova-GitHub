FROM ubuntu/bind9:latest
ENV BIND9_USER=root

RUN apt-get update && apt-get install -y --no-install-recommends dnsutils && rm -rf /var/lib/apt/lists/*

COPY named.conf.options /etc/bind/named.conf.options
COPY named.conf.local   /etc/bind/named.conf.local
COPY zones/             /etc/bind/zones/

RUN chown -R root:bind /etc/bind/zones && chmod 644 /etc/bind/zones/*
