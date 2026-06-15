# Copyright (c) 2025-2026 SIDN Labs
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

ARG UBUNTU_VERSION=26.04
FROM ubuntu:${UBUNTU_VERSION} AS build

ENV DESTDIR=/dist
#ENV CMAKE_INSTALL_PREFIX=${DESTDIR}
ENV liboqs_DIR=/liboqs

RUN mkdir -p ${DESTDIR}

RUN apt-get update -y
RUN apt-get upgrade -y
RUN apt-get install -y git build-essential libssl-dev cmake wget libgmp-dev astyle gcc ninja-build \
                     python3-pytest python3-pytest-xdist unzip xsltproc doxygen graphviz python3-yaml \
                     valgrind autoconf pkgconf libtool liburcu-dev libcap-dev libuv1-dev libjson-c-dev

RUN git clone https://github.com/open-quantum-safe/liboqs
RUN git clone https://github.com/SIDN/oqs-provider
RUN git clone https://github.com/SIDN/OQS-bind

# Build liboqs and install in /app/liboqs-bin

# XXX the checkout below will fail if progress is made on
# XXX https://github.com/open-quantum-safe/liboqs/pull/2277
# Update Elmer 15/Jun/2026: sqisign branch has performance issues fixed in commit 573fb25
# Removed support for SIG_sqisign_lvl1 for now (ELa 15/Jun/2026)
RUN cd liboqs && git checkout 97f6b86b1b6d109cfd43cf276ae39c2e776aed80 # 0.15.0
RUN cmake -S liboqs -B liboqs/build -DBUILD_SHARED_LIBS=ON -DOQS_MINIMAL_BUILD="SIG_falcon_512;SIG_mayo_2;SIG_snova_SNOVA_24_5_4;SIG_snova_SNOVA_37_17_2"
RUN cmake --build liboqs/build --parallel $(nproc)
RUN CMAKE_INSTALL_PREFIX=${DESTDIR} cmake --build liboqs/build --target install
#RUN mkdir liboqs/build
#RUN cd liboqs/build && cmake -GNinja .. 
#RUN cd liboqs/build && ninja

# Basic sanity test to verify if algorithm's integration in liboqs works
#RUN ./liboqs/build/tests/test_sig SQIsign-lvl1

# Build liboqs to /app/oqsprovider-bin
# ELa 15/Jun/2026 use our edits on top of commit 573fb25 to fix performance bug
RUN cd oqs-provider && git checkout dcdb867cd4cadb9115974b3c3ee008d56b66720c # dynamic-filter-enable-cache
RUN cd oqs-provider && liboqs_DIR=$DESTDIR/usr/local/lib/cmake/liboqs/ CFLAGS=-I$DESTDIR/usr/local/include/ cmake -S . -B _build
RUN cd oqs-provider && cmake --build _build
RUN cd oqs-provider && ctest --test-dir _build
RUN cd oqs-provider && CMAKE_INSTALL_PREFIX=${DESTDIR} cmake --install _build

#RUN cd OQS-bind && git checkout 4b5e02c72254bc0047f0480cf69018bb4b6b465d # sidnlabs-pqc
RUN cd OQS-bind && git checkout 1095f0774224c4bd785750dccc21d51d1b78f7a2 # sidnlabs-pqc (incl SNOVA support)
ENV LD_LIBRARY_PATH=/dist/usr/local/lib
ADD patches/falcon-unpadded.patch /OQS-bind/falcon-unpadded.patch
RUN cd OQS-bind && git apply  --ignore-space-change --ignore-whitespace falcon-unpadded.patch
RUN cd OQS-bind && autoreconf -fi
RUN cd OQS-bind && ./configure CC=gcc LIBS="-loqs" CFLAGS="-I$DESTDIR/usr/local/include" LDFLAGS="-L$DESTDIR/usr/local/lib -L$DESTDIR/usr/local/lib64" --disable-doh --enable-full-report
RUN cd OQS-bind && make -j$(nproc)
RUN cd OQS-bind && make install DESTDIR=${DESTDIR}

RUN echo "/usr/local/lib/bind" >> /etc/ld.so.conf.d/oqs-bind.conf
RUN ldconfig


### Now build production image

FROM ubuntu:${UBUNTU_VERSION} AS production

COPY --from=build /dist /

RUN apt-get update -y && apt-get upgrade -y && apt-get install -y libcap2 libjson-c5 libuv1-dev liburcu-dev && rm -rf /var/lib/apt/lists/*

ADD pqc-openssl.cnf /opt/pqc-openssl.cnf
ENV OPENSSL_CONF=/opt/pqc-openssl.cnf
ENV OPENSSL_MODULES=/usr/lib/x86_64-linux-gnu/ossl-modules

RUN mkdir /var/cache/bind
ADD named.conf /usr/local/etc/named.conf

RUN ldconfig

CMD named -g
