ARG deps="findutils hostname jq libpq openssl procps-ng ruby shared-mime-info tzdata"
ARG devDeps="gcc gcc-c++ gzip libffi-devel make openssl-devel patch postgresql postgresql-devel redhat-rpm-config ruby-devel tar util-linux xz"
ARG extras=""
ARG prod="true"

FROM registry.access.redhat.com/ubi9/ubi-minimal AS build

ARG deps
ARG devDeps
ARG extras
ARG prod

USER 0

WORKDIR /opt/app-root/src

COPY ./.gemrc.prod /etc/gemrc
COPY ./config/devel/dnf/ubi9.repo /etc/yum/repos.d/
COPY ./config/devel/dnf/ubi8.repo /etc/yum/repos.d/
COPY ./Gemfile.lock ./Gemfile /opt/app-root/src/

RUN microdnf install -y cpio
RUN microdnf repolist
RUN microdnf -y --disablerepo=ubi-9-baseos-rpms download $(microdnf repoquery glibc --disablerepo=ubi-9-baseos-rpms | grep 'x86_64')
# RUN microdnf --help
# RUN ls -al
RUN ls -al .
RUN rpm2cpio glibc-*.x86_64.rpm | cpio -idmv -D /tmp
RUN ls -al /tmp/
RUN ls -al /tmp/lib64
# RUN cpio --help
# RUN ls /lib64
# MALLOC_ARENA_MAX=2
# RUN cpio --help

# # add dnf
# RUN microdnf install -y yum-utils
# RUN dnf info glibc --disablerepo ubi-9-baseos-rpms
# RUN mkdir /opt/tmp/
# RUN mkdir /opt/tmp/glibc
# # get version of glibc in ubi8 repository and download the package with it's dependencies
# # FIXME: the version should not be hardcoded (?)
# RUN dnf install -y glibc-2.28-211.el8 --disablerepo ubi-9-baseos-rpms --downloadonly --allowerasing --destdir /opt/tmp/
# RUN ls -al /opt/tmp/
# # extact the rpm into folder
# RUN dnf install -y --installroot=/opt/tmp/glibc/ /opt/tmp/glibc-*.rpm
# # FIXME: fails with "RPM: error: Unable to change root directory: Operation not permitted"

RUN rpm -e --nodeps tzdata &>/dev/null                                          && \
    microdnf install --nodocs -y $deps $devDeps $extras                         && \
    chmod +t /tmp                                                               && \
    gem update --system --install-dir=/usr/share/gems --bindir /usr/bin         && \
    gem install bundler                                                         && \
    ( [[ $prod != "true" ]] || bundle config set --without 'development:test' ) && \
    ( [[ $prod != "true" ]] || bundle config set --local deployment 'true' )    && \
    ( [[ $prod != "true" ]] || bundle config set --local path './.bundle' )     && \
    bundle config set --local retry '2'                                         && \
# in .bundle/**.so -> ldd /bin/bash **.so (nokogiri, etc.) # to find out which lib was used for compilation
    LD_LIBRARY_PATH=/tmp/lib64 bundle install                                                              && \
    microdnf clean all -y                                                       && \
    ( [[ $prod != "true" ]] || bundle clean -V )

ENV prometheus_multiproc_dir=/opt/app-root/src/tmp

#############################################################

FROM registry.access.redhat.com/ubi8/ubi-minimal

ARG deps
ARG devDeps

WORKDIR /opt/app-root/src

USER 0

RUN rpm -e --nodeps tzdata &>/dev/null                                  && \
    microdnf module enable ruby:3.0                                     && \
    microdnf install --nodocs -y $deps                                  && \
    chmod +t /tmp                                                       && \
    gem update --system --install-dir=/usr/share/gems --bindir /usr/bin && \
    microdnf clean all -y                                               && \
    chown 1001:root ./                                                  && \
    install -v -d -m 1777 -o 1001 ./tmp ./log

USER 1001

COPY --chown=1001:0 . /opt/app-root/src
COPY --chown=1001:0 --from=build /opt/app-root/src/.bundle /opt/app-root/src/.bundle

#ENV LD_LIBRARY_PATH=/opt/tmp/glibc/lib64
ENV RAILS_ENV=production RAILS_LOG_TO_STDOUT=true HOME=/opt/app-root/src DEV_DEPS=$devDeps

CMD ["/opt/app-root/src/entrypoint.sh"]
