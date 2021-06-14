#!/bin/bash

#Xray版本
if [[ -z "${VER}" ]]; then
  VER="latest"
fi
echo ${VER}

if [[ -z "${Vless_Path}" ]]; then
  Vless_Path="/s233"
fi
echo ${Vless_Path}

if [[ -z "${Vless_UUID}" ]]; then
  Vless_UUID="5c301bb8-6c77-41a0-a606-4ba11bbab084"
fi
echo ${Vless_UUID}

if [[ -z "${Vmess_Path}" ]]; then
  Vmess_Path="/s244"
fi
echo ${Vmess_Path}

if [[ -z "${Vmess_UUID}" ]]; then
  Vmess_UUID="5c301bb8-6c77-41a0-a606-4ba11bbab084"
fi
echo ${Vmess_UUID}

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
    -e "s/\${Vless_UUID}/${Vless_UUID}/g"\
    -e "s|\${Vless_Path}|${Vless_Path}|g"\
    -e "s/\${Vmess_UUID}/${Vmess_UUID}/g"\
    -e "s|\${Vmess_Path}|${Vmess_Path}|g"\
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
    -e "s|\${Vless_Path}|${Vless_Path}|g"\
    -e "s|\${Vmess_Path}|${Vmess_Path}|g"\
    -e "s|\${Share_Path}|${Share_Path}|g"\
    -e "$s"\
    /conf/nginx.template.conf > /etc/nginx/conf.d/ray.conf
echo /etc/nginx/conf.d/ray.conf
cat /etc/nginx/conf.d/ray.conf


if [ "$AppName" = "no" ]; then
  echo "不生成分享链接"
else
  [ ! -d /wwwroot/${Share_Path} ] && mkdir -p /wwwroot/${Share_Path}
  path=$(echo -n "${Vless_Path}?ed=2048" | sed -e 's/\//%2F/g' -e 's/=/%3D/g' -e 's/;/%3B/g' -e 's/\?/%3F/g')
  vless_link="vless://${Vless_UUID}@${AppName}.herokuapp.com:443?path=${path}&security=tls&encryption=none&type=ws#${AppName}-herokuapp-Vless"
  path=$(echo -n "${Vmess_Path}?ed=2048" | sed -e 's/\//%2F/g' -e 's/=/%3D/g' -e 's/;/%3B/g' -e 's/\?/%3F/g')
  vmess_link="vmess://${Vmess_UUID}@${AppName}.herokuapp.com:443?path=${path}&security=tls&encryption=none&type=ws#${AppName}-herokuapp-Vmess"
  echo -n "${vless_link}" | tr -d '\n' > /wwwroot/${Share_Path}/index.html
  echo "" >> /wwwroot/${Share_Path}/index.html
  echo -n "${vmess_link}" | tr -d '\n' >> /wwwroot/${Share_Path}/index.html
  cat /wwwroot/${Share_Path}/index.html
  echo -n "${vless_link}" | qrencode -s 6 -o /wwwroot/${Share_Path}/vless.png
  echo -n "${vmess_link}" | qrencode -s 6 -o /wwwroot/${Share_Path}/vmess.png
fi

cd /xraybin
./xray run -c ./config.json &
rm -rf /etc/nginx/sites-enabled/default
nginx -g 'daemon off;'
