#!/bin/sh

echo "    _              __ _     _      _ __     __   "
echo "   | |     ___    / _\` |   (_)    | '_ \\   / /   "
echo "   | |    / _ \\   \\__, |   | |    | .__/  / _ \\  "
echo "  _|_|_   \\___/   |___/   _|_|_   |_|__   \\___/  "
echo "_|\"\"\"\"\"|_|\"\"\"\"\"|_|\"\"\"\"\"|_|\"\"\"\"\"|_|\"\"\"\"\"|_|\"\"\"\"\"| "
echo "\"\`-0-0-'\"\`-0-0-'\"\`-0-0-'\"\`-0-0-'\"\`-0-0-'\"\`-0-0-' "
echo ""
echo "parameter e.g.: --otp="your_base32_otp" --ip=0.0.0.0 --port=8080 --interface=ens192"
echo ""
# 解析命令行参数
while [ $# -gt 0 ]; do
  case "$1" in
    --otp=*)
      OTP="${1#*=}"
      ;;
    --ip=*)
      IP="${1#*=}"
      ;;
    --port=*)
      PORT="${1#*=}"
      ;;
    --interface=*)
      INTERFACE="${1#*=}"
      ;;
    *)
      echo "Invalid argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

# 默认值处理
OTP="${OTP:-$OATH_OTP}"
IP="${IP:-${OATH_IP:-127.0.0.1}}"
PORT="${PORT:-${OATH_PORT:-8080}}"
INTERFACE="${INTERFACE:-${OATH_INTERFACE:-eth0}}"

# 生成base32的随机字符串
generate_otp() {
  head -c 10 /dev/urandom | base32
}

# 如果没有传入OTP, 再尝试从文件读取, 还读取不到就生成一个默认的
if [ -z "$OTP" ]; then

  # 如果没有传入OTP, 尝试从文件读取
  if [ -f "$HOME/.config/OATH_WEB_OTP" ]; then
    OTP=$(cat $HOME/.config/OATH_WEB_OTP)
    echo "OTP: $OTP"
  fi
  
  if [ -z "$OTP" ]; then
    OTP=$(generate_otp)
    echo "Generated OTP: $OTP"
  fi

else
  echo "OTP: $OTP"
fi

# otpauth://totp/{label}?secret={secret}&issuer={issuer}&algorithm={algorithm}&digits={digits}&period={period}
qrencode -t UTF8 "otpauth://totp/log6ip?secret=$OTP&issuer=log6ip&algorithm=SHA1&digits=6&period=30"

if [ ! -d "$HOME/.config" ]; then
    # 如果 .config 目录不存在，则创建
    mkdir -p "$HOME/.config"
fi

echo "$OTP" > $HOME/.config/OATH_WEB_OTP
echo "INTERFACE: $INTERFACE"

# 初始化Web服务
init_web_service() {
  lighttpd_config="/etc/lighttpd/lighttpd.conf"
  
  # 生成lighttpd的配置文件
  cat <<EOF > $lighttpd_config
server.modules = (
    "mod_alias",
    "mod_accesslog",
    "mod_cgi",
    "mod_rewrite"
)

server.document-root       = "/var/www/localhost/htdocs"
server.port                = $PORT
server.bind                = "$IP"
server.errorlog            = "/var/log/lighttpd/error.log"
accesslog.filename         = "/var/log/lighttpd/access.log"

url.rewrite-once = (
    "^/([0-9]{6})\$" => "/index.sh"
)

cgi.assign = (
    ".sh" => "/bin/sh"
)

EOF

  # 创建Web根目录和CGI脚本
  mkdir -p /var/www/localhost/htdocs
  cat <<EOF > /var/www/localhost/htdocs/index.sh
#!/bin/sh

# 获取请求的 URI,提取 '/TOTP_VALUE' 部分
TOTP_VALUE=\$(echo "\$REQUEST_URI" | sed 's,/$,,' | cut -d'/' -f2)

# 只允许字母数字字符
if [[ ! "\$TOTP_VALUE" =~ ^[0-9]{6}$ ]]; then
    echo "Content-Type: text/plain"
    echo ""
    echo "Invalid TOTP"
    exit 1
fi

# 如果你想手动测试,可以执行: oathtool --totp -b GNW44OGCPX4RIR6R | grep ^142753$
if oathtool --totp -b "$OTP" | grep -q "^\$TOTP_VALUE\$"; then
    # ip_address=\$(ip -6 a s "$INTERFACE" | grep -oP '(?<=inet6\s)[\da-f:]+(?=/)')
    ip_address=\$(ip -6 a s "$INTERFACE"| grep inet6 | grep secondary | grep -v deprecated | awk '{print \$2}' | cut -d/ -f1)
    echo "Content-Type: text/plain"
    echo ""
    echo "\$ip_address"
else
    echo "Content-Type: text/plain"
    echo ""
    echo "Invalid TOTP"
fi
EOF

  chmod +x /var/www/localhost/htdocs/index.sh

}

# 初始化Web服务
init_web_service

# 启动lighttpd服务
echo "LISTEN: $IP:$PORT"
lighttpd -D -f $lighttpd_config
