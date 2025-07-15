FROM ubuntu:24.04
RUN apt-get update -y
RUN apt-get upgrade -y
RUN apt-get install -y git build-essential libssl-dev cmake wget
RUN apt-get install -y autoconf pkgconf libtool liburcu-dev libcap-dev libuv1-dev

RUN wget https://github.com/openssl/openssl/releases/download/openssl-3.4.0/openssl-3.4.0.tar.gz && tar xzf openssl-3.4.0.tar.gz
RUN cd openssl-3.4.0 && ./Configure --openssldir=/opt/openssl --prefix=/opt/openssl && make -j && make install

RUN git clone https://github.com/open-quantum-safe/liboqs.git liboqs
RUN git clone https://github.com/open-quantum-safe/oqs-provider.git oqs-provider
RUN git clone https://github.com/SIDN/OQS-bind.git

ENV PATH="/opt/openssl/bin:$PATH"
ENV LD_LIBRARY_PATH="/opt/openssl/lib:/opt/openssl/lib64:$LD_LIBARY_PATH"
ENV OPENSSL_ROOT_DIR="/opt/openssl"
ENV liboqs_DIR="$OPENSSL_ROOT_DIR"

# Build liboqs and install in /app/liboqs-bin

RUN cd liboqs && git checkout 0.13.0
RUN cmake -S liboqs -B liboqs/build -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=$liboqs_DIR -DOQS_BUILD_ONLY_LIB=ON
RUN cmake --build liboqs/build --parallel 4
RUN cmake --build liboqs/build --target install

# Build liboqs to /app/oqsprovider-bin
RUN cd oqs-provider && git checkout 0.9.0
RUN cd oqs-provider && cmake -S . -B _build
RUN cd oqs-provider && cmake --build _build
RUN cd oqs-provider && cmake --install _build

ADD pqc-openssl.cnf /opt/pqc-openssl.cnf
ENV OPENSSL_CONF=/opt/pqc-openssl.cnf

RUN (test -f /opt/openssl/lib64/ossl-modules/oqsprovider.so && sed -i /opt/pqc-openssl.cnf -e 's#/opt/openssl/lib#/opt/openssl/lib64#g') || :

RUN cd OQS-bind && git checkout 2aeb0420392282d062feeb6831ae885d08ce2b6c
ADD patches/falcon-unpadded.patch /OQS-bind/falcon-unpadded.patch
RUN cd OQS-bind && git apply  --ignore-space-change --ignore-whitespace falcon-unpadded.patch
RUN cd OQS-bind && autoreconf -fi
RUN cd OQS-bind && ./configure CC=gcc LIBS="-loqs" CFLAGS="-I$liboqs_DIR/include" LDFLAGS="-L$liboqs_DIR/lib -L$liboqs_DIR/lib64" --with-openssl=$OPENSSL_ROOT_DIR --disable-doh --enable-full-report
RUN cd OQS-bind && make -j
RUN cd OQS-bind && make install

RUN echo "/opt/openssl/lib" > /etc/ld.so.conf.d/oqs-bind.conf
RUN echo "/opt/openssl/lib64" >> /etc/ld.so.conf.d/oqs-bind.conf
RUN echo "/usr/local/lib/bind" >> /etc/ld.so.conf.d/oqs-bind.conf
RUN ldconfig

#cleanup

RUN rm -rf /openssl-3.4.0
RUN rm -rf /OQS-bind
RUN rm -rf /oqs-provider
RUN rm -rf /liboqs

RUN mkdir /var/cache/bind
ADD named.conf /usr/local/etc/named.conf

CMD named -g
#ENTRYPOINT /OQS-bind/bin/dnssec/dnssec-signzone
