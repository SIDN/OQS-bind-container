# Copyright (c) 2025 SIDN Labs
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

FROM ubuntu:24.04
RUN apt-get update -y
RUN apt-get upgrade -y
RUN apt-get install -y git build-essential libssl-dev cmake wget
RUN apt-get install -y autoconf pkgconf libtool liburcu-dev libcap-dev libuv1-dev
RUN apt-get install -y libgmp-dev

RUN wget https://github.com/openssl/openssl/releases/download/openssl-3.4.3/openssl-3.4.3.tar.gz && tar xzf openssl-3.4.3.tar.gz
RUN echo "fa727ed1399a64e754030a033435003991aee36bda9a5b080995cb2ac5cf7f37  openssl-3.4.3.tar.gz" | sha256sum -c -
RUN cd openssl-3.4.3 && ./Configure --openssldir=/opt/openssl --prefix=/opt/openssl && make -j$(nproc) && make install

RUN git clone https://github.com/open-quantum-safe/liboqs
RUN git clone https://github.com/SIDN/oqs-provider
RUN git clone https://github.com/SIDN/OQS-bind.git

ENV PATH="/opt/openssl/bin:$PATH"
ENV LD_LIBRARY_PATH="/opt/openssl/lib:/opt/openssl/lib64:$LD_LIBARY_PATH"
ENV OPENSSL_ROOT_DIR="/opt/openssl"
ENV liboqs_DIR="$OPENSSL_ROOT_DIR"

# Build liboqs and install in /app/liboqs-bin

RUN cd liboqs && git checkout 9686ba3704757f8fdcc191c754d34c79ad95f5cf # sqisign
RUN cmake -S liboqs -B liboqs/build -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=$liboqs_DIR
RUN cmake --build liboqs/build --parallel $(nproc)
RUN cmake --build liboqs/build --target install
# Basic sanity test to verify if algorithm's integration in liboqs works
RUN ./liboqs/build/tests/test_sig SQIsign-lvl1

# Build liboqs to /app/oqsprovider-bin
RUN cd oqs-provider && git checkout 6d87d2994fada77f0e3408e0baf357b89932d149 # wip-sqisign
RUN cd oqs-provider && cmake -S . -B _build
RUN cd oqs-provider && cmake --build _build
RUN cd oqs-provider && cmake --install _build

ADD pqc-openssl.cnf /opt/pqc-openssl.cnf
ENV OPENSSL_CONF=/opt/pqc-openssl.cnf

RUN (test -f /opt/openssl/lib64/ossl-modules/oqsprovider.so && sed -i /opt/pqc-openssl.cnf -e 's#/opt/openssl/lib#/opt/openssl/lib64#g') || :

RUN cd OQS-bind && git checkout bded5721f0b2929d875f57c756abbca4b357c097 # sidnlabs-pqc
ADD patches/falcon-unpadded.patch /OQS-bind/falcon-unpadded.patch
RUN cd OQS-bind && git apply  --ignore-space-change --ignore-whitespace falcon-unpadded.patch
RUN cd OQS-bind && autoreconf -fi
RUN cd OQS-bind && ./configure CC=gcc LIBS="-loqs" CFLAGS="-I$liboqs_DIR/include" LDFLAGS="-L$liboqs_DIR/lib -L$liboqs_DIR/lib64" --with-openssl=$OPENSSL_ROOT_DIR --disable-doh --enable-full-report
RUN cd OQS-bind && make -j$(nproc)
RUN cd OQS-bind && make install

RUN echo "/opt/openssl/lib" > /etc/ld.so.conf.d/oqs-bind.conf
RUN echo "/opt/openssl/lib64" >> /etc/ld.so.conf.d/oqs-bind.conf
RUN echo "/usr/local/lib/bind" >> /etc/ld.so.conf.d/oqs-bind.conf
RUN ldconfig

#cleanup

RUN rm -rf /openssl-3.4.3
RUN rm -rf /OQS-bind
RUN rm -rf /oqs-provider
RUN rm -rf /liboqs

RUN mkdir /var/cache/bind
ADD named.conf /usr/local/etc/named.conf

CMD named -g
#ENTRYPOINT /OQS-bind/bin/dnssec/dnssec-signzone
