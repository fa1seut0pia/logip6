FROM alpine:latest

# 如果本地构建时你的网不行,可以取消sed开头的镜像替换命令注释
RUN  \
    # sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories && \
    apk update && \
    apk add --no-cache --virtual .build-deps \
        build-base \
        autoconf \
        automake \
        libtool \
        git \
        libpng-dev \
        && \
    git clone --depth 1 https://github.com/fukuchi/libqrencode.git && \
    cd libqrencode && \
    ./autogen.sh && \
    ./configure --prefix=/usr && \
    make && \
    make install && \
    cd .. && \
    rm -rf libqrencode && \
    apk del .build-deps && \
    apk add --no-cache libpng oath-toolkit-oathtool coreutils lighttpd && \
    rm -rf /var/cache/apk/*

COPY lighttpd_oash_get_ip6.sh /entrypoint.sh

CMD ["sh", "/entrypoint.sh"]

# 端口可能修改,因此不添加 EXPOSE
# EXPOSE 8080
