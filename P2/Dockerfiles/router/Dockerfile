FROM alpine:latest

RUN apk update && apk add --no-cache \
    frr \
    iproute2 \
    net-tools

# Ensure the run directory exists
RUN mkdir -p /run/frr && chown -R frr:frr /run/frr

# Enable daemons
RUN sed -i 's/zebra=no/zebra=yes/' /etc/frr/daemons && \
    sed -i 's/bgpd=no/bgpd=yes/' /etc/frr/daemons && \
    sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons && \
    sed -i 's/isisd=no/isisd=yes/' /etc/frr/daemons

# Create dummy config files
RUN touch /etc/frr/zebra.conf \
          /etc/frr/bgpd.conf \
          /etc/frr/ospfd.conf \
          /etc/frr/isisd.conf && \
    chown -R frr:frr /etc/frr

# FIX: Start the services AND then run a tail command to keep the container open
ENTRYPOINT ["sh", "-c", "/usr/lib/frr/frrinit.sh start && tail -f /dev/null"]