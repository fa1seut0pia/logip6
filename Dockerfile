FROM alpine:latest

# 如果本地构建时你的网不行,可以取消sed开头的镜像替换命令注释
RUN  \
    # sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories && \
    apk update && \
    apk add --no-cache oath-toolkit-oathtool coreutils lighttpd

COPY lighttpd_oash_get_ip6.sh /lighttpd_oash_get_ip6.sh

CMD ["sh", "/lighttpd_oash_get_ip6.sh"]

# 端口可能修改,因此不添加 EXPOSE
# EXPOSE 8080
