#!/bin/sh

#remove the "/" from V2_Path and V2_QR_Code
V2_Path=$(echo "${V2_Path}" | sed 's/^\/*//')
V2_QR_Path=$(echo "${V2_QR_Path}" | sed 's/^\/*//')

SYS_Bit="$(getconf LONG_BIT)"
[ "${SYS_Bit}" == '32' ] && BitVer='386'
[ "${SYS_Bit}" == '64' ] && BitVer='amd64'

if [ "$VER" = "latest" ]; then
  V_VER=$(wget -qO- https://api.github.com/repos/v2fly/v2ray-core/releases/latest | jq . | jq ".tag_name" | tr -d '"')
else
  V_VER="v${VER}"
fi

mkdir -p /v2ray
cd /v2ray
wget https://github.com/v2fly/v2ray-core/releases/download/${V_VER}/v2ray-linux-${SYS_Bit}.zip
unzip v2ray-linux-${SYS_Bit}.zip -d /v2ray/
rm -f /v2ray/v2ray-linux-${SYS_Bit}.zip
chmod 0755 /v2ray/v2ray
chmod 0755 /v2ray/v2ctl

mkdir -p /www/wwwroot
unzip /demo.zip -d /www/wwwroot/
rm /demo.zip

cat << EOF | tee /v2ray/config.json
{
    "log":{
        "loglevel":"warning"
    },
    "inbound":{
        "protocol":"vmess",
        "listen":"127.0.0.1",
        "port":2333,
        "settings":{
            "clients":[
                {
                    "id":"${UUID}",
                    "level":0,
                    "alterId":${AlterID}
                }
            ]
        },
        "streamSettings":{
            "network":"ws",
            "wsSettings":{
                "path":"/${V2_Path}"
            }
        }
    },
    "outbound":{
        "protocol":"freedom",
        "settings":{
        }
    },
    "policy": {
        "levels": {
            "0": {
                "handshake": 3,
                "connIdle": 30,
                "uplinkOnly": 1,
                "downlinkOnly": 3,
                "statsUserUplink": false,
                "statsUserDownlink": false,
                "bufferSize": ${V2_BUFFER_SIZE}
            }
        },
        "system": {
            "statsInboundUplink": false,
            "statsInboundDownlink": false
        }
    }
}
EOF

mkdir /caddy/
cd /caddy/
wget https://github.com/caddyserver/caddy/releases/download/v1.0.4/caddy_v1.0.4_linux_${BitVer}.tar.gz
tar -zxvf caddy_v1.0.4_linux_${BitVer}.tar.gz caddy
chmod 0755 caddy

SERVER_NAME=${AppName}.herokuapp.com

cat << EOF | tee /caddy/Caddyfile
*:${PORT} {
    proxy /${V2_Path} 127.0.0.1:2333 {
        header_upstream Connection {>Connection}
        header_upstream Upgrade {>Upgrade}
    }
    root /www/wwwroot
    basicauth /${V2_QR_Path} ${ADMIN_USER} ${ADMIN_PASSWORD}
}
EOF

cat <<-EOF > /v2ray/v2ray_qr.json
{
    "v": "2",
    "ps": "${AppName}.herokuapp.com",
    "add": "${AppName}.herokuapp.com",
    "port": "443",
    "id": "${UUID}",
    "aid": "${AlterID}",
    "net": "ws",
    "type": "none",
    "host": "",
    "path": "/${V2_Path}",
    "tls": "tls"
}
EOF

mkdir /www/wwwroot/${V2_QR_Path}
if [ "$(echo "${GenQR}" | tr '[A-Z]' '[a-z]')" = "no" ]; then
  echo "不生成二维码"
else
  vmess="vmess://$(cat /v2ray/v2ray_qr.json | base64 -w 0)"
  Linkbase64=$(echo -n "${vmess}" | tr -d '\n' | base64 -w 0)
  echo "${Linkbase64}" | tr -d '\n' > /www/wwwroot/${V2_QR_Path}/index.html
  echo -n "${vmess}" | qrencode -s 6 -o /www/wwwroot/${V2_QR_Path}/v2ray.png
  rm /v2ray/v2ray_qr.json
fi

export PATH="/v2ray:/caddy:$PATH"
/caddy/caddy -conf /caddy/Caddyfile &
/v2ray/v2ray -config /v2ray/config.json
