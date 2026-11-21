# Copyright 2026 vfox-erlang contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# E2E image for the vfox-erlang plugin on Ubuntu.
#
# The image holds the toolchain only. The repository is mounted at run time and
# is never copied in, so build from the repository root:
#
#   docker build -t vfox-erlang-e2e:22.04 --build-arg UBUNTU_VERSION=22.04 tests/e2e/linux
#   docker run --rm -v "$PWD:/src:ro" vfox-erlang-e2e:22.04
#
# Ubuntu 22.04 and 24.04 are supported. The wx packages differ between them, and
# libncurses5-dev exists only on 22.04, so the RUN step below picks the list.

ARG UBUNTU_VERSION=22.04

# Go toolchain. Only /usr/local/go is copied into the final image.
FROM golang:1.27.1 AS go

FROM ubuntu:${UBUNTU_VERSION}

ARG VFOX_VERSION=1.1.0

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8

# Erlang/OTP build dependencies. No Erlang packages are installed here: the
# TestLinuxSystemDetect needs erlang-base, which the run command installs with apt.
RUN . /etc/os-release \
    && if [ "$VERSION_ID" = "24.04" ]; then \
         WX="libwxgtk3.2-dev libwxgtk-webview3.2-dev"; NCURSES5=""; \
       else \
         WX="libwxgtk3.0-gtk3-dev libwxgtk-webview3.0-gtk3-dev"; NCURSES5="libncurses5-dev"; \
       fi \
    && apt-get update \
    && apt-get install -y ca-certificates curl git zip unzip build-essential autoconf m4 $NCURSES5 $WX libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils libncurses-dev openjdk-11-jdk \
    && rm -rf /var/lib/apt/lists/*

COPY --from=go /usr/local/go /usr/local/go
ENV PATH=/usr/local/go/bin:/root/go/bin:$PATH
ENV GOPATH=/root/go

# vfox 1.1.0 is the first release with `vfox link --detect`, which the tests use.
RUN go install github.com/version-fox/vfox@v${VFOX_VERSION} \
    && install -m 0755 /root/go/bin/vfox /usr/local/bin/vfox \
    && vfox --version \
    && vfox link --help > /dev/null

ENV VFOX_BIN=/usr/local/bin/vfox
ENV E2E_REPO=/src
ENV GOFLAGS=

WORKDIR /src

CMD ["sh", "-c", "cd /src/tests/e2e && go test -v -timeout 90m -run TestLinux ./linux"]
