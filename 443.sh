#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Current folder
cur_dir=$(pwd)
# Color
red='\033[0;31m'
green='\033[0;32m'
#yellow='\033[0;33m'
plain='\033[0m'
operation=(Install Update UpdateConfig logs restart delete)
# Make sure only root can run our script
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] Ê Cu Cho Xin Nhẹ Quyền ROOT Nào!" && exit 1

#Check system
check_sys() {
  local checkType=$1
  local value=$2
  local release=''
  local systemPackage=''

  if [[ -f /etc/redhat-release ]]; then
    release="centos"
    systemPackage="yum"
  elif grep -Eqi "debian|raspbian" /etc/issue; then
    release="debian"
    systemPackage="apt"
  elif grep -Eqi "ubuntu" /etc/issue; then
    release="ubuntu"a
    systemPackage="apt"
  elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
    release="centos"
    systemPackage="yum"
  elif grep -Eqi "debian|raspbian" /proc/version; then
    release="debian"
    systemPackage="apt"
  elif grep -Eqi "ubuntu" /proc/version; then
    release="ubuntu"
    systemPackage="apt"
  elif grep -Eqi "centos|red hat|redhat" /proc/version; then
    release="centos"
    systemPackage="yum"
  fi

  if [[ "${checkType}" == "sysRelease" ]]; then
    if [ "${value}" == "${release}" ]; then
      return 0
    else
      return 1
    fi
  elif [[ "${checkType}" == "packageManager" ]]; then
    if [ "${value}" == "${systemPackage}" ]; then
      return 0
    else
      return 1
    fi
  fi
}

# Get version
getversion() {
  if [[ -s /etc/redhat-release ]]; then
    grep -oE "[0-9.]+" /etc/redhat-release
  else
    grep -oE "[0-9.]+" /etc/issue
  fi
}

# CentOS version
centosversion() {
  if check_sys sysRelease centos; then
    local code=$1
    local version="$(getversion)"
    local main_ver=${version%%.*}
    if [ "$main_ver" == "$code" ]; then
      return 0
    else
      return 1
    fi
  else
    return 1
  fi
}

get_char() {
  SAVEDSTTY=$(stty -g)
  stty -echo
  stty cbreak
  dd if=/dev/tty bs=1 count=1 2>/dev/null
  stty -raw
  stty echo
  stty $SAVEDSTTY
}
error_detect_depends() {
  local command=$1
  local depend=$(echo "${command}" | awk '{print $4}')
  echo -e "[${green}Info${plain}] Đang Cài Chờ Chút ${depend}"
  ${command} >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "[${red}Error${plain}] Tạch Rồi M Ơi ${red}${depend}${plain}"
    exit 1
  fi
}

# Pre-installation settings
pre_install_docker_compose() {
#install key_path
    echo -e "[${Green}Key Hợp Lệ${plain}] Link Web : https://yunagrp.com"
    read -p " Xin ID nút 80 Nào (Node_ID_Vmess):" node_id_vmess
    [ -z "${node_id_vmess}" ] && node_id=0
    echo "-------------------------------"
    echo -e "Node_ID: ${node_id_vmess}"
    echo "-------------------------------"

    read -p " Xin ID nút 443 nào (Node_ID_Trojan):" node_id_trojan
    [ -z "${node_id_trojan}" ] && node_id=0
    echo "-------------------------------"
    echo -e "Node_ID: ${node_id_trojan}"
    echo "-------------------------------"

    read -p "Vui long nhập CertDomain :" CertDomain
    [ -z "${CertDomain}" ] && CertDomain=0
    echo "-------------------------------"
    echo -e "Domain: ${CertDomain}"
    echo "-------------------------------"

# giới hạn tốc độ
    read -p " Giới hạn tốc độ (Mbps):" limit_speed
    [ -z "${limit_speed}" ] && limit_speed=0
    echo "-------------------------------"
    echo -e "Giới hạn tốc độ: ${limit_speed}"
    echo "-------------------------------"

# giới hạn thiết bị
    read -p " Giới hạn thiết bị (Limit):" limit
    [ -z "${limit}" ] && limit=0
    echo "-------------------------------"
    echo -e "Limit: ${limit}"
    echo "-------------------------------"
}

# Config docker
config_docker() {
  cd ${cur_dir} || exit
  echo "Bắt đầu cài đặt các gói"
  install_dependencies
  echo "Tải tệp cấu hình DOCKER"
  cat >docker-compose.yml <<EOF
version: '3'
services: 
  xrayr: 
    image: yunagrp/xrayr:v1.7.4
    volumes:
      - ./yuna.yml:/etc/XrayR/yuna.yml # thư mục cấu hình bản đồ
      - ./dns.json:/etc/XrayR/dns.json 
      - ./YunaBlock:/etc/XrayR/YunaBlock
      - ./server.pem:/etc/XrayR/server.pem
      - ./privkey.pem:/etc/XrayR/privkey.pem
    restart: always
    network_mode: host
EOF
  cat >dns.json <<EOF
{
    "servers": [
        "1.1.1.1",
        "8.8.8.8",
        "localhost"
    ],
    "tag": "dns_inbound"
}
EOF

  cat >yuna.yml <<EOF
Log:
  Level: none # Log level: none, error, warning, info, debug 
  AccessPath: # /etc/XrayR/access.Log
  ErrorPath: # /etc/XrayR/error.log
DnsConfigPath: # /etc/XrayR/dns.json # Path to dns config, check https://xtls.github.io/config/dns.html for help
RouteConfigPath: # /etc/XrayR/route.json # Path to route config, check https://xtls.github.io/config/routing.html for help
InboundConfigPath: # /etc/XrayR/custom_inbound.json # Path to custom inbound config, check https://xtls.github.io/config/inbound.html for help
OutboundConfigPath: # /etc/XrayR/custom_outbound.json # Path to custom outbound config, check https://xtls.github.io/config/outbound.html for help
ConnetionConfig:
  Handshake: 4 # Handshake time limit, Second
  ConnIdle: 30 # Connection idle time limit, Second
  UplinkOnly: 2 # Time limit when the connection downstream is closed, Second
  DownlinkOnly: 4 # Time limit when the connection is closed after the uplink is closed, Second
  BufferSize: 64 # The internal cache size of each connection, kB 
Nodes:
  -
    PanelType: "V2board" # Panel type: SSpanel, V2board, PMpanel, Proxypanel
    ApiConfig:
      ApiHost: "https://lightspeed4g.pw"
      ApiKey: "ultimate1234yuna"
      NodeID: $node_id_trojan
      NodeType: Trojan # Node type: V2ray, Trojan, Shadowsocks, Shadowsocks-Plugin
      Timeout: 30 # Timeout for the api request
      EnableVless: false # Enable Vless for V2ray Type
      EnableXTLS: false # Enable XTLS for V2ray and Trojan
      SpeedLimit: $limit_speed # Mbps, Local settings will replace remote settings, 0 means disable
      DeviceLimit: $limit # Local settings will replace remote settings, 0 means disable
      RuleListPath: /etc/XrayR/YunaBlock # ./rulelist Path to local rulelist file
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      DisableUploadTraffic: false # Disable Upload Traffic to the panel
      DisableGetRule: false # Disable Get Rule from the panel
      DisableIVCheck: false # Disable the anti-reply protection for Shadowsocks
      EnableProxyProtocol: false # Only works for WebSocket and TCP
      EnableFallback: false # Only support for Trojan and Vless
      FallBackConfigs:  # Support multiple fallbacks
        -
          SNI: # TLS SNI(Server Name Indication), Empty for any
          Path: # HTTP PATH, Empty for any
          Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/fallback/ for details.
          ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for dsable
      CertConfig:
        CertMode: file # Option about how to get certificate: none, file, http, dns. Choose "none" will forcedly disable the tls config.
        CertDomain: "$CertDomain" # Domain to cert
        CertFile: /etc/XrayR/server.pem # Provided if the CertMode is file
        KeyFile: /etc/XrayR/privkey.pem
        Provider: cloudflare # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
        Email: test@me.com
        DNSEnv: # DNS ENV option used by DNS provider
          CLOUDFLARE_EMAIL: aaa
          CLOUDFLARE_API_KEY: bbb
  -
    PanelType: "V2board" # Panel type: SSpanel, V2board, PMpanel, Proxypanel
    ApiConfig:
      ApiHost: "https://lightspeed4g.pw"
      ApiKey: "ultimate1234yuna"
      NodeID: $node_id_vmess
      NodeType: V2ray # Node type: V2ray, Trojan, Shadowsocks, Shadowsocks-Plugin
      Timeout: 30 # Timeout for the api request
      EnableVless: false # Enable Vless for V2ray Type
      EnableXTLS: false # Enable XTLS for V2ray and Trojan
      SpeedLimit: $limit_speed # Mbps, Local settings will replace remote settings, 0 means disable
      DeviceLimit: $limit # Local settings will replace remote settings, 0 means disable
      RuleListPath: /etc/XrayR/YunaBlock # ./rulelist Path to local rulelist file
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      SendIP: 0.0.0.0 # IP address you want to send pacakage
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Use custom DNS config, Please ensure that you set the dns.json well
      DNSType: AsIs # AsIs, UseIP, UseIPv4, UseIPv6, DNS strategy
      DisableUploadTraffic: false # Disable Upload Traffic to the panel
      DisableGetRule: false # Disable Get Rule from the panel
      DisableIVCheck: false # Disable the anti-reply protection for Shadowsocks
      EnableProxyProtocol: false # Only works for WebSocket and TCP
      EnableFallback: false # Only support for Trojan and Vless
      FallBackConfigs:  # Support multiple fallbacks
        -
          SNI: # TLS SNI(Server Name Indication), Empty for any
          Path: # HTTP PATH, Empty for any
          Dest: 80 # Required, Destination of fallback, check https://xtls.github.io/config/fallback/ for details.
          ProxyProtocolVer: 0 # Send PROXY protocol version, 0 for dsable
      CertConfig:
        CertMode: file # Option about how to get certificate: none, file, http, dns. Choose "none" will forcedly disable the tls config.
        CertDomain: "$CertDomain" # Domain to cert
        CertFile: /etc/XrayR/server.pem # Provided if the CertMode is file
        KeyFile: /etc/XrayR/privkey.pem
        Provider: cloudflare # DNS cert provider, Get the full support list here: https://go-acme.github.io/lego/dns/
        Email: test@me.com
        DNSEnv: # DNS ENV option used by DNS provider
          CLOUDFLARE_EMAIL: aaa
          CLOUDFLARE_API_KEY: bbb
EOF

    cat >server.pem <<EOF
-----BEGIN CERTIFICATE-----
MIIEqjCCA5KgAwIBAgIUel32m/WKU3fpmqaU6isu2Jmu9RAwDQYJKoZIhvcNAQEL
BQAwgYsxCzAJBgNVBAYTAlVTMRkwFwYDVQQKExBDbG91ZEZsYXJlLCBJbmMuMTQw
MgYDVQQLEytDbG91ZEZsYXJlIE9yaWdpbiBTU0wgQ2VydGlmaWNhdGUgQXV0aG9y
aXR5MRYwFAYDVQQHEw1TYW4gRnJhbmNpc2NvMRMwEQYDVQQIEwpDYWxpZm9ybmlh
MB4XDTIzMDMyMjE4MDkwMFoXDTM4MDMxODE4MDkwMFowYjEZMBcGA1UEChMQQ2xv
dWRGbGFyZSwgSW5jLjEdMBsGA1UECxMUQ2xvdWRGbGFyZSBPcmlnaW4gQ0ExJjAk
BgNVBAMTHUNsb3VkRmxhcmUgT3JpZ2luIENlcnRpZmljYXRlMIIBIjANBgkqhkiG
9w0BAQEFAAOCAQ8AMIIBCgKCAQEAkVyXlcjpZuUwo121avI9UGaMiZUhf2tgw6Cd
1rMv6gEDG5XcDshWfUbPjeRQZl6liZaE8YspRnUywsuFoX8XGAy+PFKR0WIf93oa
x5Ujcf1dkBatP6fpMF/aFbSFMLA55rXXLUsJNU6vHEWBYAQC6NnDUW/bHtXaqTdN
hT7Bhgu1KNYVo8hpMLw59+LqmbvK2k2DzYuOimAGNsVN5y70p3jDHoT4ZukY2/Vu
EU9divquroqup4GSuZSOLtWO+/A/ee/Sa0S03MbDBOUSJ5ZhVKluIjUWf+wtdIUG
rZ4fbiCSIcIyBHs+LZK8V1c+e/pXzip8ejrr2CK5snCakQ5TYQIDAQABo4IBLDCC
ASgwDgYDVR0PAQH/BAQDAgWgMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcD
ATAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBQlj0HH2PjrGYXiBd/RvzXZea/Y/DAf
BgNVHSMEGDAWgBQk6FNXXXw0QIep65TbuuEWePwppDBABggrBgEFBQcBAQQ0MDIw
MAYIKwYBBQUHMAGGJGh0dHA6Ly9vY3NwLmNsb3VkZmxhcmUuY29tL29yaWdpbl9j
YTAtBgNVHREEJjAkghEqLmxpZ2h0c3BlZWQ0Zy5wd4IPbGlnaHRzcGVlZDRnLnB3
MDgGA1UdHwQxMC8wLaAroCmGJ2h0dHA6Ly9jcmwuY2xvdWRmbGFyZS5jb20vb3Jp
Z2luX2NhLmNybDANBgkqhkiG9w0BAQsFAAOCAQEARA7kFOZSa7lR6IVuvMJ5NGg5
xTEFmuv+e7tA74yjYX261/CT77htEMe5iVvQCNaVFX2WgvPM0MDVlLAXW0Qf8JhH
qJps/8VomhBOeq30+GDkh274voLC36Pvu25bUESKI/+S1JU5tYYvV3ha8Fva07Do
T52TW5LVG2CBuKxOI/ygrTEQPP6Le2uwzevgT5n0uZhZ2ucDsVug7bCjwDH0BUcD
IeBemRzueF3pm10iCr5v5yIGkluf1U6MIt0tRbuYjGtC5lHqwhQTewiMprfVf4Qh
+uoHdg0+wOWCnBIcbsQglc6cPoA3GWmlAisv6l4vGSDsIeHiOyMAPCro8Ledvw==
-----END CERTIFICATE-----
EOF

    cat >privkey.pem <<EOF
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCRXJeVyOlm5TCj
XbVq8j1QZoyJlSF/a2DDoJ3Wsy/qAQMbldwOyFZ9Rs+N5FBmXqWJloTxiylGdTLC
y4WhfxcYDL48UpHRYh/3ehrHlSNx/V2QFq0/p+kwX9oVtIUwsDnmtdctSwk1Tq8c
RYFgBALo2cNRb9se1dqpN02FPsGGC7Uo1hWjyGkwvDn34uqZu8raTYPNi46KYAY2
xU3nLvSneMMehPhm6Rjb9W4RT12K+q6uiq6ngZK5lI4u1Y778D9579JrRLTcxsME
5RInlmFUqW4iNRZ/7C10hQatnh9uIJIhwjIEez4tkrxXVz57+lfOKnx6OuvYIrmy
cJqRDlNhAgMBAAECggEAAVOfIguz/p+JnLoUl2nnz5mp/3D0He+20b4/5oda4Pe6
pagt2pgvOuQ4LXc3mSGUwO9V3gb7PNSBvrehC/bnGO332ADYahjrSgTMJQVqTgZm
EdQ1J1My3IFJciCERSwckSuYb8ZDKqCB1mAXhM7wkFu5bb83uJ2yyc/ShixrE3w5
F2+DmuQjHDTLmb0c098arSmtyeBIDIxC+CS8aTa3lHu1EA+v3AhGqsqDJXkYcx2N
HYUM948bJu+3RRpwYOwX1NGTsbX5i/s/D4KA1tBundOvw+eUvC2/mEJB44iWGLEr
g0EYwAV/BI5TC4OcJ6mqUYNmz7+tJeBP4ipZwI8mAQKBgQDMmonvfmKwJiBfJqRS
MI3WZTQ+HeDuWssfmijtdbeivJHCyM8VIsKM65sizLQQ1ZCc1X+3R1wfc0M58zZc
VnidE4DiiLRP47aKL13PrYqBHTdCB6gOiUPyyrHCMnu/eRDk067M/+TybHCLCYrx
/Vm+BD4aK7pXiUHweHZfwj1Q4QKBgQC14GAkC+839U1zwsL7EpdiSWWxF3smOWZZ
FwoHjABDOega6qf1QWrjb9/pXkpVO2EXAcrujfcHSt5EonerMF3mK2h1PuMaW8Dc
3TSBawDwGjZECG0xJ54AIXZT0XD3B9U4YqBrjEQaMM2eWoSyPi7Ces8WUzcq1gma
UO+eTdDSgQKBgFXY+cs9MldKiAakhgneSYUNjbAKhVg9TEEEQ+vumpBzoo0iCJGL
tim+qaceUOdHVJgZlK7oCCVCDZEBFWwE9DKj/k4OoelrWCn+2dPLsvOduJPB9qey
vIngtlkPKZEbURVSJGPrcrqs+UO9S0lhzgfGa/A7LMKR2tL1GGXxcBzBAoGBAKSZ
3GjDJEzQhLgvm6b+vGMHajFLvvhpGmemoj0SR2qQDa/OjxM3kTUlGtBptXxNsSDR
Tod3lAnViDM1lngn3dNhlbgGoiJIx9Mbn1lBLigekN4hgjDqWeRkZGKXOlVXkXDm
UakD2N6bLHwUD+QAwvDflGvwBA2QiEBQ34u1gTgBAoGABuMO9W0HcWw9eg0Jy1Go
/xaJf+MVPHLoAZB5fVd1oOulnCjmw28m4bZfpnxAWdC1sf4uwYEpAABKNY6OcdUe
IYRa0335g7K1O+ts+sX1kXO9C1BqagQ8r0D6Iubv+/960aC+9CAY3mPTIc0rd6O0
NTBeB+mq/rYHgdWwKMTpDuM=
-----END PRIVATE KEY-----
EOF

    cat >YunaBlock <<EOF
.*whatismyip.*
(.*.||)(ipaddress|whatismyipaddress|whoer|iplocation|whatismyip|checkip|ipaddress|showmyip).(org|com|net|my|to|co|vn|my)
(.*\.||)(speed|speedtest|fast|speed.cloudflare|speedtest.xfinity|speedtestcustom|speedof|testmy|i-speed|speedtest.vnpt|nperf|speedtest.telstra|i-speed|merter|speed|speedcheck|zingfast)\.(com|cn|net|co|xyz|dev|edu|pro|vn|me|io|org|io)
EOF
}

# Install docker and docker compose
install_docker() {
  echo -e "bắt đầu cài đặt DOCKER "
 sudo apt-get update
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get install docker-ce docker-ce-cli containerd.io -y
systemctl start docker
systemctl enable docker
  echo -e "bắt đầu cài đặt Docker Compose "
curl -fsSL https://get.docker.com | bash -s docker
curl -L "https://github.com/docker/compose/releases/download/1.26.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
  echo "khởi động Docker "
  service docker start
  echo "khởi động Docker-Compose "
  docker-compose up -d
  echo
  echo -e "Đã hoàn tất cài đặt phụ trợ ！"
  echo -e "0 0 */3 * *  cd /root/${cur_dir} && /usr/local/bin/docker-compose pull && /usr/local/bin/docker-compose up -d" >>/etc/crontab
  echo -e "Cài đặt cập nhật thời gian kết thúc đã hoàn tất! YunaGRP scr sẽ update sau [${green}24H${plain}] Từ lúc bạn cài đặt"
}

install_check() {
  if check_sys packageManager yum || check_sys packageManager apt; then
    if centosversion 5; then
      return 1
    fi
    return 0
  else
    return 1
  fi
}

install_dependencies() {
  if check_sys packageManager yum; then
    echo -e "[${green}Info${plain}] Kiểm tra kho EPEL ..."
    if [ ! -f /etc/yum.repos.d/epel.repo ]; then
      yum install -y epel-release >/dev/null 2>&1
    fi
    [ ! -f /etc/yum.repos.d/epel.repo ] && echo -e "[${red}Error${plain}] Không cài đặt được kho EPEL, vui lòng kiểm tra." && exit 1
    [ ! "$(command -v yum-config-manager)" ] && yum install -y yum-utils >/dev/null 2>&1
    [ x"$(yum-config-manager epel | grep -w enabled | awk '{print $3}')" != x"True" ] && yum-config-manager --enable epel >/dev/null 2>&1
    echo -e "[${green}Info${plain}] Kiểm tra xem kho lưu trữ EPEL đã hoàn tất chưa ..."

    yum_depends=(
      curl
    )
    for depend in ${yum_depends[@]}; do
      error_detect_depends "yum -y install ${depend}"
    done
  elif check_sys packageManager apt; then
    apt_depends=(
      curl
    )
    apt-get -y update
    for depend in ${apt_depends[@]}; do
      error_detect_depends "apt-get -y install ${depend}"
    done
  fi
  echo -e "[${green}Info${plain}] Đặt múi giờ thành Tây Ninh GTM+7"
  ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh  /etc/localtime
  date -s "$(curl -sI g.cn | grep Date | cut -d' ' -f3-6)Z"

}

#update_image
Update_xrayr() {
  cd ${cur_dir}
  echo "Tải hình ảnh DOCKER YunaGRP"
  docker-compose pull
  echo "Bắt đầu chạy dịch vụ DOCKER YunaGRP"
  docker-compose up -d
}

#show last 100 line log

logs_xrayr() {
  echo "100 dòng nhật ký chạy sẽ được hiển thị"
  docker-compose logs --tail 100
}

# Update config
UpdateConfig_xrayr() {
  cd ${cur_dir}
  echo "đóng dịch vụ hiện tại"
  docker-compose down
  pre_install_docker_compose
  config_docker
  echo "Bắt đầu chạy dịch vụ DOKCER YunaGRP"
  docker-compose up -d
}

restart_xrayr() {
  cd ${cur_dir}
  docker-compose down
  docker-compose up -d
  echo "Khởi động lại thành công!"
}
delete_xrayr() {
  cd ${cur_dir}
  docker-compose down
  echo "đã xóa thành công!"
}
# Install xrayr
Install_xrayr() {
  pre_install_docker_compose
  config_docker
  install_docker
}

# Initialization step
clear
while true; do
  echo "Vui lòng nhập một số để Thực Hiện Câu Lệnh:"
  for ((i = 1; i <= ${#operation[@]}; i++)); do
    hint="${operation[$i - 1]}"
    echo -e "${green}${i}${plain}) ${hint}"
  done
  read -p "Vui lòng chọn một số và nhấn Enter (Enter theo mặc định ${operation[0]}):" selected
  [ -z "${selected}" ] && selected="1"
  case "${selected}" in
  1 | 2 | 3 | 4 | 5 | 6 | 7)
    echo
    echo "Bắt Đầu : ${operation[${selected} - 1]}"
    echo
    ${operation[${selected} - 1]}_xrayr
    break
    ;;
  *)
    echo -e "[${red}Error${plain}] Vui lòng nhập số chính xác [1-6]"
    ;;
  esac
done
