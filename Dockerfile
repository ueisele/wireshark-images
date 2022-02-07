ARG DEBIAN_RELEASE=bullseye
ARG WIRESHARK_VERSION=3.6.1
ARG WIRESHARK_BRANCH=v${WIRESHARK_VERSION}

## Build Wireshark ##
FROM debian:${DEBIAN_RELEASE} as wireshark-build

ARG WIRESHARK_BRANCH
ADD https://gitlab.com/wireshark/wireshark/-/raw/${WIRESHARK_BRANCH}/tools/debian-setup.sh /
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
	&& apt-get install gnupg apt-utils ca-certificates -y \
	&& apt-get update \
	&& chmod +x debian-setup.sh \
	&& ./debian-setup.sh -y --install-optional --install-deb-deps --install-test-deps \
		python3-pytest-xdist doxygen locales \
        gcc-10 g++-10 clang-9 \
    && apt-get clean -y \
	&& rm -rf /var/lib/apt/lists/
ENV DEBIAN_FRONTEND=dialog

RUN cd /root && git clone https://gitlab.com/wireshark/wireshark.git
RUN cd /root/wireshark \
	&& git pull \
	&& git checkout ${WIRESHARK_BRANCH}
RUN cd /root/wireshark \
	&& dpkg-buildpackage -us -uc -rfakeroot \
	&& git clean -Xdf
RUN find /root/ -maxdepth 1 -type f -regextype posix-egrep -regex "^.*-(dev|dbg|doc)_[0-9_.]+_(amd64|arm64|all)\.deb$" -delete


## Create Base Image ##
FROM debian:${DEBIAN_RELEASE}-slim as net-tools

# Install tools
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
	&& apt-get install gnupg apt-utils ca-certificates locales -y \
	&& apt-get update \
	&& apt-get -y install procps neovim less expect jq net-tools iproute2 nftables iputils-ping iputils-tracepath iputils-arping \
		telnet ldnsutils netcat socat tcpdump hping3 curl wget httpie \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*
ARG LOCALE=en_US
RUN sed -i -e "s/# *${LOCALE}.UTF-8 UTF-8/${LOCALE}.UTF-8 UTF-8/" /etc/locale.gen && \
	sed -i -e "s/# *de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/" /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=${LOCALE}.UTF-8
ENV LANG ${LOCALE}.UTF-8
ENV DEBIAN_FRONTEND=dialog

# Install tini init daemon
ARG TINI_VERSION=v0.19.0
ARG TARGETARCH
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-${TARGETARCH} /usr/local/tini
RUN chmod +x /usr/local/tini
ENTRYPOINT ["/usr/local/tini", "--"]
CMD ["/bin/bash"]

# Add permissions to run network tools as non root user
RUN setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip' $(whereis -b tcpdump | cut -d" " -f2)
RUN setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip' $(whereis -b nft | cut -d" " -f2)
RUN setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip' $(whereis -b tc | cut -d" " -f2)
RUN setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip' $(whereis -b hping3 | cut -d" " -f2)

# Add user
RUN useradd -m -s /bin/bash -d /home/debian -u 1000 -U debian
USER debian

# Set workdir
WORKDIR /home/debian

# Set tools related labels
ARG DEBIAN_RELEASE
LABEL debian.release=${DEBIAN_RELEASE}


## Create Tshark Image ##
FROM net-tools as tshark

# Switch to root user for installation
USER root

# Copy install script
COPY install-deb.sh /root/

# Copy Tshark deb files
COPY --from=wireshark-build /root/*.deb /root/wireshark-deb/

# Install TShark
ENV DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH
RUN apt-get update \
	&& /root/install-deb.sh --deb-dir "/root/wireshark-deb/" "/root/wireshark-deb/tshark_+([[:digit:]_.])_${TARGETARCH}.deb"  \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* \
	&& rm -rf /root/wireshark-deb/ \
	&& rm /root/install-deb.sh
ENV DEBIAN_FRONTEND=dialog

# Add permissions to run tshark as non root user
RUN setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip' $(whereis -b dumpcap | cut -d" " -f2)

# Switch to non root user
USER debian

# Set tools related labels
ARG WIRESHARK_VERSION
ARG WIRESHARK_BRANCH
LABEL wireshark.version=${WIRESHARK_VERSION}
LABEL wireshark.branch=${WIRESHARK_BRANCH}

# Set default cmd
ENTRYPOINT ["/usr/local/tini", "--", "/usr/bin/tshark"]
CMD []


## Create Termshark image ##
FROM tshark as termshark

# Switch to root user for installation
USER root

# Install Termshark
ARG TERMSHARK_VERSION=2.3.0
ARG TARGETARCH
RUN	if [ ${TARGETARCH} = "amd64" ]; then \
		arch=x64 ;\
	else \
		arch=${TARGETARCH}; \
	fi ;\
	curl -L https://github.com/gcla/termshark/releases/download/v${TERMSHARK_VERSION}/termshark_${TERMSHARK_VERSION}_linux_${arch}.tar.gz | tar -xz --strip-components=1 -C /usr/bin
LABEL termshark.version=${TERMSHARK_VERSION}

# Switch to non root user
USER debian

# Set default cmd
ENTRYPOINT ["/usr/local/tini", "--", "/usr/bin/termshark"]
CMD []


## Create Xpra base image ##
FROM net-tools as net-tools-xpra

# Switch to root user for installation
USER root

# Install xpra
ARG DEBIAN_RELEASE
ENV DEBIAN_FRONTEND=noninteractive
RUN curl -Ls --ipv4  https://xpra.org/gpg.asc | apt-key add -
RUN curl -Ls --ipv4 -o /etc/apt/sources.list.d/xpra.list https://xpra.org/repos/${DEBIAN_RELEASE}/xpra.list
RUN apt-get update \
	&& apt-get install -y xpra websockify python3-pyinotify menu-xdg \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*
ENV DEBIAN_FRONTEND=dialog

# Configure Xpra for docker
RUN sed -i 's/^\(socket-dirs.*\)$/#\1/g' /etc/xpra/conf.d/10_network.conf
COPY ./xpra_docker.conf /etc/xpra/conf.d/90_xpra_docker.conf

# create default certificate and allow wireshark user to read it
RUN openssl req -new -x509 -days 3650 -nodes -newkey RSA:2048 -sha256 \
		-subj "/C=DE/ST=Hessen/L=Frankfurt/O=ueisele/OU=xpra/CN=localhost" \
		-out /etc/xpra/cert.pem -keyout /etc/xpra/key.pem \
	&& cat /etc/xpra/key.pem /etc/xpra/cert.pem > /etc/xpra/ssl-cert.pem \
	&& chmod 644 /etc/xpra/ssl-cert.pem \
	&& rm /etc/xpra/cert.pem \
	&& rm /etc/xpra/key.pem

# create run directory for xpra socket and set correct permissions
RUN mkdir -p /run/user/$(id -u debian)/xpra \
	&& chown -R debian:xpra /run/user/$(id -u debian)
RUN usermod -a -G xpra debian

# Switch to non root user
USER debian

# set default password to access wireshark via xpra
ENV XPRA_PW debian

# expose xpra default port
EXPOSE 14500

# run xpra, options --daemon and --no-printing only work if specified as parameters to xpra start
ENTRYPOINT ["/usr/local/tini", "--", "/usr/bin/xpra", "start", ":10", "--daemon=no"]
CMD ["--start-child=xterm", "--exit-with-children=yes"]


## Create wireshark image ##
FROM net-tools-xpra as wireshark

# Switch to root user for installation
USER root

# Copy install script
COPY install-deb.sh /root/

# Copy Wireshark deb files
COPY --from=wireshark-build /root/*.deb /root/wireshark-deb/

# Install Wireshark
ENV DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH
RUN apt-get update \
	&& /root/install-deb.sh --deb-dir "/root/wireshark-deb/" "/root/wireshark-deb/wireshark_+([[:digit:]_.])_${TARGETARCH}.deb"  \
    && apt-get clean -y \
	&& rm -rf /root/wireshark-deb/ \
	&& rm /root/install-deb.sh
ENV DEBIAN_FRONTEND=dialog

# Add permissions to run tshark as non root user
RUN setcap 'CAP_NET_RAW+eip CAP_NET_ADMIN+eip' $(whereis -b dumpcap | cut -d" " -f2)

# copy xpra config file
COPY ./xpra_wireshark.conf /etc/xpra/xpra.conf

# Switch to non root user
USER debian

# Set tools related labels
ARG WIRESHARK_VERSION
ARG WIRESHARK_BRANCH
LABEL wireshark.version=${WIRESHARK_VERSION}
LABEL wireshark.branch=${WIRESHARK_BRANCH}

# run xpra, options --daemon and --no-printing only work if specified as parameters to xpra start
CMD []