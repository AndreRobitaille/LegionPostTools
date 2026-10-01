# Cloud Agent base image. Cursor checks out the repository after this image is
# built, so this file installs only the toolchain and PostgreSQL. Do not copy
# the application into the image.
#
# This is not the production image. Production stays in the repository-root Dockerfile.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    PATH="/opt/hostedtoolcache/Ruby/4.0.0/x64/bin:/usr/local/bin:${PATH}"

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl sudo \
    && rm -rf /var/lib/apt/lists/* \
    && (id -u ubuntu >/dev/null 2>&1 || useradd --create-home --shell /bin/bash --uid 1000 ubuntu) \
    && echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu \
    && chmod 0440 /etc/sudoers.d/ubuntu

# RUBY_VERSION must match .ruby-version. The repository is not in the image,
# so the script cannot read that file during the image build.
COPY setup-system.sh /tmp/setup-system.sh
RUN RUBY_VERSION=4.0.0 bash /tmp/setup-system.sh && rm /tmp/setup-system.sh

USER ubuntu
WORKDIR /workspace
