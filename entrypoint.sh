#!/bin/bash

#Xray版本
if [[ -z "${VER}" ]]; then
  VER="latest"
fi
echo ${VER}

if [[ -z "${Xray_Path}" ]]; then
  Xray_Path="/s233"
fi
echo ${Xray_Path}

if [[ -z "${UUID}" ]]; then
  UUID="5c301bb8-6c77-41a0-a606-4ba11bbab084"
fi
echo ${UUID}

if [[ -z "${Share_Path}" ]]; then
  Share_Path="/share233"
fi
echo ${Share_Path}

if [ "$VER" = "latest" ]; then
  VER=`wget -qO- "https://api.github.com/repos/XTLS/Xray-core/releases/latest" | sed -n -r -e 's/.*"tag_name".+?"([vV0-9\.]+?)".*/\1/p'`
  [[ -z "${VER}" ]] && VER="v1.2.2"
else
  VER="v$VER"
fi

mkdir /xraybin
cd /xraybin
RAY_URL="https://github.com/XTLS/Xray-core/releases/download/${VER}/Xray-linux-64.zip"
echo ${RAY_URL}
wget --no-check-certificate ${RAY_URL}
unzip Xray-linux-64.zip
rm -f Xray-linux-64.zip
chmod +x ./xray
ls -al

cd /wwwroot
tar xvf wwwroot.tar.gz
rm -rf wwwroot.tar.gz


sed -e "/^#/d"\
    -e "s/\${UUID}/${UUID}/g"\
    -e "s|\${Xray_Path}|${Xray_Path}|g"\
    /conf/Xray.template.json >  /xraybin/config.json
echo /xraybin/config.json
cat /xraybin/config.json

if [[ -z "${ProxySite}" ]]; then
  s="s/proxy_pass/#proxy_pass/g"
  echo "site:use local wwwroot html"
else
  s="s|\${ProxySite}|${ProxySite}|g"
  echo "site: ${ProxySite}"
fi

sed -e "/^#/d"\
    -e "s/\${PORT}/${PORT}/g"\
    -e "s|\${Xray_Path}|${Xray_Path}|g"\
    -e "s|\${Share_Path}|${Share_Path}|g"\
    -e "$s"\
    /conf/nginx.template.conf > /etc/nginx/conf.d/ray.conf
echo /etc/nginx/conf.d/ray.conf
cat /etc/nginx/conf.d/ray.conf


if [ "$AppName" = "no" ]; then
  echo "不生成分享链接"
else
cat <<-EOF > /xraybin/vmess.json
{
    "v": "2",
    "ps": "${AppName}.herokuapp.com",
    "add": "${AppName}.herokuapp.com",
    "port": "443",
    "id": "${UUID}",
    "aid": "0",
    "net": "ws",
    "type": "none",
    "host": "",
    "path": "${Xray_Path}",
    "tls": "tls"
}
EOF

  [ ! -d /wwwroot/${Share_Path} ] && mkdir /wwwroot/${Share_Path}
  vmess="vmess://$(cat /xraybin/vmess.json | jq -c | base64 -w 0)"
  echo -n "${vmess}" | tr -d '\n' > /wwwroot/${Share_Path}/index.html
  link=$(echo -n "${vmess}" | tr -d '\n' | base64 -w 0)
  echo -n "${link}" | tr -d '\n' > /wwwroot/${Share_Path}/sub.html
  cat /wwwroot/${Share_Path}/index.html
  echo -n "${link}" | qrencode -s 6 -o /wwwroot/${Share_Path}/vmess.png
fi

cd /xraybin
./xray run -c ./config.json &
rm -rf /etc/nginx/sites-enabled/default
nginx -g 'daemon off;'
