#!/bin/bash

[[ -z "${MY_TOKEN}" ]] && MY_TOKEN="2023"


[[ -z "${REPO}" ]] && REPO="v2fly/v2ray-core"
[[ -z "${VER}" ]] && VER="latest"
[[ -z "${Vless_Path}" ]] && Vless_Path=/l`echo $MY_TOKEN | md5sum | cut -c 1-9`
[[ -z "${Vless_UUID}" ]] && Vless_UUID="5c301bb8-6c77-41a0-a606-4ba11bbab084"
[[ -z "${Vmess_Path}" ]] && Vmess_Path=/m`echo $MY_TOKEN | md5sum | cut -c 1-9`
[[ -z "${Vmess_UUID}" ]] && Vmess_UUID="5c301bb8-6c77-41a0-a606-4ba11bbab084"
[[ -z "${Share_Path}" ]] && Share_Path=/share_${MY_TOKEN}
[[ -z "${PORT}" ]] && PORT=80


echo $Share_Path


if [ "$VER" = "latest" ]; then
  VER=`wget -qO- "https://api.github.com/repos/${REPO}/releases/latest" | sed -n -r -e 's/.*"tag_name".+?"([vV0-9\.]+?)".*/\1/p'`
else
  VER="v$VER"
fi

if [ "$REPO" = "v2fly/v2ray-core" ]; then
  PACKAGE="v2ray-linux-64.zip"
else
  PACKAGE="Xray-linux-64.zip"
fi

mkdir /raybin && cd /raybin
RAY_URL="https://github.com/${REPO}/releases/download/${VER}/${PACKAGE}"
echo ${RAY_URL}
wget --no-check-certificate ${RAY_URL}
unzip $PACKAGE
rm -f $PACKAGE
BIN=`ls *ray`
chmod +x ./$BIN
ls -al

cd /wwwroot
tar xvf wwwroot.tar.gz
rm -rf wwwroot.tar.gz

sed -e "/^#/d"\
    -e "s/\${Vless_UUID}/${Vless_UUID}/g"\
    -e "s|\${Vless_Path}|${Vless_Path}|g"\
    -e "s/\${Vmess_UUID}/${Vmess_UUID}/g"\
    -e "s|\${Vmess_Path}|${Vmess_Path}|g"\
    /conf/ray.template.json >  /raybin/config.json
echo /raybin/config.json
cat /raybin/config.json

if [[ -z "${ProxySite}" ]]; then
  s="s/.+ProxySite.+/#no ProxySite/g"
  echo "site:use local wwwroot html"
else
  s="s|\\$\{ProxySite\}|${ProxySite}|g"
  echo "site: ${ProxySite}"
fi

sed -e "/^#/d"\
    -e "s/\${PORT}/${PORT}/g"\
    -e "s|\${Vless_Path}|${Vless_Path}|g"\
    -e "s|\${Vmess_Path}|${Vmess_Path}|g"\
    -e "s|\${Share_Path}|${Share_Path}|g"\
    -E "$s"\
    /conf/nginx.template.conf > /etc/nginx/conf.d/ray.conf
echo /etc/nginx/conf.d/ray.conf
cat /etc/nginx/conf.d/ray.conf

[ ! -d /wwwroot/${Share_Path} ] && mkdir -p /wwwroot/${Share_Path}
sed -e "/^#/d"\
    -e "s|\${_Vless_Path}|${Vless_Path}|g"\
    -e "s|\${_Vmess_Path}|${Vmess_Path}|g"\
    -e "s/\${_Vless_UUID}/${Vless_UUID}/g"\
    -e "s/\${_Vmess_UUID}/${Vmess_UUID}/g"\
    /conf/share.html > /wwwroot/${Share_Path}/index.html
echo /wwwroot/${Share_Path}/index.html
cat /wwwroot/${Share_Path}/index.html

cd /raybin
./$BIN run -c ./config.json &
rm -rf /etc/nginx/sites-enabled/default
nginx -g 'daemon off;'
