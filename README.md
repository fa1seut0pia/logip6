# 一个开放web服务的shell脚本,用于获取服务器IPv6地址

## 0x00 使用方式

```shell

curl http://域名/{6位TOTP值}

```

## 0x02 依赖安装

### 1. Alpine

```shell

# docker 运行可跳过此步骤
# 可选 sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories
apk add oath-toolkit-oathtool coreutils lighttpd

```

## 0x03 运行方式

### 1. docker (推荐)

环境变量  
`OATH_OTP`: OTP base32 字符串, 默认随机生成, 需要通过 `docker logs -f logip6` 的方式查看生成的结果    
`OATH_IP`: 监听的 IP, 默认 `127.0.0.1`   
`OATH_PORT`: 监听的 PORT, 默认 `8080` , 端口冲突就修改  
`OATH_INTERFACE`: 要获取 IP 的网卡名称, 默认 `eth0`  

可以挂载 `OATH_WEB_SECRET` 文件, 比如 `-v ./OATH_WEB_SECRET:~/.config/OATH_WEB_SECRET`  

```shell

# 以后台运行的方式启动
docker run -d --name logip6 --network host --restart always -e OATH_INTERFACE=ens192 fa1seut0pias/logip6

# 查看日志
docker logs -f logip6

```

构建

```shell

docker build -t logip6:latest .

```

### 2. 普通方式

```shell

# 变量方式运行
OATH_OTP="your_base32_secret" OATH_IP="192.168.1.10" OATH_PORT="8080" OATH_INTERFACE="eth0" ./lighttpd_oash_get_ip6.sh

# 参数方式运行
./lighttpd_oash_get_ip6.sh --secret="your_base32_secret" --ip=0.0.0.0 --port=8080 --interface=ens192

# 不指定 secret 会从文件 ~/.config/OATH_WEB_SECRET 获取, 获取不到会随机生成, 再写进 ~/.config/OATH_WEB_SECRET 
sh /lighttpd_oash_get_ip6.sh --port=8080 --ip=127.0.0.1 --interface=ens192

```

## 0x04 实现设计

使用shell在Alpine Linux(便于docker化)开发一个web服务,  

此服务只提供一个查询接口   

接口地址预期是 http://域名/{6位TOTP值}   

接口内部的实现是先校验TOTP值, 校验通过就返回服务器的现在的IPv6地址(因为IPv6会变,这也是写这个脚本的原因)   

脚本名字 lighttpd_oash_get_ip6.sh   

脚本依赖 coreutils 的 base32 lighttpd 和  oath-toolkit-oathtool   

脚本需要有两个函数:

1. 生成 base32的随机字符串   
2. 启动 lighttpd web服务

脚本支持4个参数,  otp, ip, port, 以及网卡名字 interface, 4个参数有默认值也都支持从环境变量获取

如果 otp 没传, 生成默认 otp, 也就是 base32 的随机字符串

如果获取到了 otp, 则以传入的 otp 启动服务
