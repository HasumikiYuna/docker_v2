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
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] Chưa vào root kìa !, vui lòng xin phép ROOT trước!" && exit 1

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
    release="ubuntu"
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
  echo -e "[${green}Info${plain}] Bắt đầu cài đặt các gói ${depend}"
  ${command} >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo -e "[${red}Error${plain}] Cài đặt gói không thành công ${red}${depend}${plain}"
    exit 1
  fi
}

# Pre-installation settings
pre_install_docker_compose() {
#install key_path
    echo -e "[${Green}Key Hợp Lệ${plain}] Link Web : https://aikocute.com"
    read -p " ID nút (Node_ID_Vmess):" node_id_vmess
    [ -z "${node_id_vmess}" ] && node_id=0
    echo "-------------------------------"
    echo -e "Node_ID: ${node_id_vmess}"
    echo "-------------------------------"

    read -p " ID nút (Node_ID_Trojan):" node_id_trojan
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
    image: aikocute/xrayr:v1.7.4
    volumes:
      - ./aiko.yml:/etc/XrayR/aiko.yml # thư mục cấu hình bản đồ
      - ./dns.json:/etc/XrayR/dns.json 
      - ./AikoBlock:/etc/XrayR/AikoBlock
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

  cat >aiko.yml <<EOF
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
      ApiHost: "https://shopvpn.net"
      ApiKey: "adminquangtien1234@gmail.com"
      NodeID: $node_id_trojan
      NodeType: Trojan # Node type: V2ray, Trojan, Shadowsocks, Shadowsocks-Plugin
      Timeout: 30 # Timeout for the api request
      EnableVless: false # Enable Vless for V2ray Type
      EnableXTLS: false # Enable XTLS for V2ray and Trojan
      SpeedLimit: $limit_speed # Mbps, Local settings will replace remote settings, 0 means disable
      DeviceLimit: $limit # Local settings will replace remote settings, 0 means disable
      RuleListPath: /etc/XrayR/AikoBlock # ./rulelist Path to local rulelist file
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
      ApiHost: "https://shopvpn.net"
      ApiKey: "adminquangtien1234@gmail.com"
      NodeID: $node_id_vmess
      NodeType: V2ray # Node type: V2ray, Trojan, Shadowsocks, Shadowsocks-Plugin
      Timeout: 30 # Timeout for the api request
      EnableVless: false # Enable Vless for V2ray Type
      EnableXTLS: false # Enable XTLS for V2ray and Trojan
      SpeedLimit: $limit_speed # Mbps, Local settings will replace remote settings, 0 means disable
      DeviceLimit: $limit # Local settings will replace remote settings, 0 means disable
      RuleListPath: /etc/XrayR/AikoBlock # ./rulelist Path to local rulelist file
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
MIIEojCCA4qgAwIBAgIUSkeFKtQalNoaUIxYYIWDF6qBimAwDQYJKoZIhvcNAQEL
BQAwgYsxCzAJBgNVBAYTAlVTMRkwFwYDVQQKExBDbG91ZEZsYXJlLCBJbmMuMTQw
MgYDVQQLEytDbG91ZEZsYXJlIE9yaWdpbiBTU0wgQ2VydGlmaWNhdGUgQXV0aG9y
aXR5MRYwFAYDVQQHEw1TYW4gRnJhbmNpc2NvMRMwEQYDVQQIEwpDYWxpZm9ybmlh
MB4XDTIzMDIxNzAzMDIwMFoXDTM4MDIxMzAzMDIwMFowYjEZMBcGA1UEChMQQ2xv
dWRGbGFyZSwgSW5jLjEdMBsGA1UECxMUQ2xvdWRGbGFyZSBPcmlnaW4gQ0ExJjAk
BgNVBAMTHUNsb3VkRmxhcmUgT3JpZ2luIENlcnRpZmljYXRlMIIBIjANBgkqhkiG
9w0BAQEFAAOCAQ8AMIIBCgKCAQEA8JdfO/erpWQc7rR2elM6cyHDp46ie77HY2Mf
Jyd9hjciholopsVNndL7yRdM1s7d/iWR0IFkWusnlpT+TH/U0Evziop4NNdsHBTj
C504QkN3Hoc3QEBe/TwU/PBynaoQwEwRUmT1i3mSPwawPB99H4+0qhmF+A0fDJKU
OPuHybM4zlkoUGHmnz8y9vbMPlu9Ql0+9mS8buGMN+etdJ683RzyUi0GOAu556xT
Nx+VssvzVvt2Dm5XwoDdGm9VNkcLCNyDIowV+TWI9fkt+PgdoG5QvGa2wc3u2cCY
sKVNnwizfAE+Bvk4QbFdLgaz+JJ35a15OSuwXAhAj0XB3YEyWQIDAQABo4IBJDCC
ASAwDgYDVR0PAQH/BAQDAgWgMB0GA1UdJQQWMBQGCCsGAQUFBwMCBggrBgEFBQcD
ATAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBTegOz8DmSnw5ytzvgSpg3X+8Mf7zAf
BgNVHSMEGDAWgBQk6FNXXXw0QIep65TbuuEWePwppDBABggrBgEFBQcBAQQ0MDIw
MAYIKwYBBQUHMAGGJGh0dHA6Ly9vY3NwLmNsb3VkZmxhcmUuY29tL29yaWdpbl9j
YTAlBgNVHREEHjAcgg0qLnNob3B2cG4ubmV0ggtzaG9wdnBuLm5ldDA4BgNVHR8E
MTAvMC2gK6AphidodHRwOi8vY3JsLmNsb3VkZmxhcmUuY29tL29yaWdpbl9jYS5j
cmwwDQYJKoZIhvcNAQELBQADggEBAL0I5zehXCVHN770+6hzlBnYVsK2CZW3gtPj
mMSSWgRRBKkpx4AoyCIOneSsC4K/IOTtD+RtcVhPONGwAwJd1clB4TQfhPicRoiF
OReDfzFNuavuesAfzAJsOPNN9P6421OYOsk6WivVRvw338PkHCeuNToY1SmhwJ7W
j8XOp8lO3KNp9PoZCQC0VadmKcVcOYyLWyZVk26eZXW054q2eYlXUTpnFWRA3mvS
+EhKeNle5WovBXaRjAKaMq2OUAvJtjsTyBEm2X12MRaErRQ8oUabwuQ2X/MVi3sQ
3XFzFI0v/trCGWbAHR5DSqRrQVgUOAdJrCwJtwvGnS3CH5kxeM8=
-----END CERTIFICATE-----
EOF
    cat >privkey.pem <<EOF
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDwl18796ulZBzu
tHZ6UzpzIcOnjqJ7vsdjYx8nJ32GNyKGiWimxU2d0vvJF0zWzt3+JZHQgWRa6yeW
lP5Mf9TQS/OKing012wcFOMLnThCQ3cehzdAQF79PBT88HKdqhDATBFSZPWLeZI/
BrA8H30fj7SqGYX4DR8MkpQ4+4fJszjOWShQYeafPzL29sw+W71CXT72ZLxu4Yw3
5610nrzdHPJSLQY4C7nnrFM3H5Wyy/NW+3YOblfCgN0ab1U2RwsI3IMijBX5NYj1
+S34+B2gblC8ZrbBze7ZwJiwpU2fCLN8AT4G+ThBsV0uBrP4knflrXk5K7BcCECP
RcHdgTJZAgMBAAECggEAFiginZ+v/5HKNlOJS7epfNvhrGcu4I2PyD/jKRRyc29V
byVtbVpjTQMWrAzIx0mS2Sp1lMmtx8+7PBtplfr5ytsLyTj6XAdwzd9Aj5vBiBy1
dirGtFSZSuIDHs44B/wXAdafi8J/eIJQLRy9EzRlLghqf3XNSCxRLTO8kcjcVv9M
Jmr8z06Cpx1776Q6NnKeYzTnPSS6IL81LxbKms5chWATFiTwxqungjTSPtL06qhn
iBzd6nAOLTLhin93wB+QjdBuWWrDKkwOAxd11Zz8nwHEDUvh5HpEHKDbPIUjoEep
qgQHF3Cq/XlrrzfPF8q5NwGQVx3RmaQmVcNkIOFfXwKBgQD8xW5OG+RelGbeG2TM
aqUMRIbW5OEUWGhqa0leOWtgcdyVoRnojsfRjKOkRalkv7DPLWZgTbPcszqefEhw
FoJwqC9nwv/xepEBdE/IJa5gxLqR1hxG079ht2gY25B/wqx2X4UcRG8dZqcqvnak
F3ewQqVNnqCk4h9CjTUnM/omkwKBgQDzqhzJhe+nEGq6JB2NnYN1zs6wbXkVZOgj
Cbgh5+s4H01SWqw3/yOJb2aSlQd/SV2u95QbsweGI/31Q9PKx7MZWqzNltpPq96l
nY0cD7ISB3rdHj1oV+ty0dePs3jbSe3VP7P3tMO6xyv+36WC3TBef/E63Z3pHwYc
koCAWlvK4wKBgQDAUleDBqXTcIZ0J9Oh1OKPWvRdPPgkSr/neInyLy4Ly5ZSIqlb
0IcoYSGBM5+XEGKuv5RNYdGf8p5/R4C2B+pnXQ/0muGyEdeSi7TITCNJbWWm4InT
Ofk7mBiUETr4el5OEo9s2oTQkfJPC2upnlFqwsqTLEZ+La4rLNVsZpfGEQKBgQCo
WYBKPB+4bb9PnGRO0+VgH+LuQrTF81Hv42c1BeeefwINRFh41+7VpgJYhF8Jssbn
fGb4PFmWdIeiTZqnIBK+EcgSw4dSRI0wIAq+uJlvm3toCtyimxwx2In23ylBWXLZ
Q4o0OtCA29up3RudrvUcVYl2Amh4CNdQJmhiRgvlwQKBgBGEWhb/04OqNc5M+pBR
VD5RyHlIhXIXoZJE0fJAO1WYBPlCWNuGwUTt8Znl2kQX9v63K7rKYzI9bvEYrbnO
lrQbH5fnNWj+qp0YvPYBCUrXbzoETnxnuf5evGfwstw9FXiiD1uRhp2dsWhDnHtG
idCk4HB1baPX4eP5jacLMytr
-----END PRIVATE KEY-----
EOF

    cat >AikoBlock <<EOF
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
  echo -e "Cài đặt cập nhật thời gian kết thúc đã hoàn tất! hệ thống sẽ update sau [${green}24H${plain}] Từ lúc bạn cài đặt"
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
  echo -e "[${green}Info${plain}] Đặt múi giờ thành Hồ Chí Minh GTM+7"
  ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh  /etc/localtime
  date -s "$(curl -sI g.cn | grep Date | cut -d' ' -f3-6)Z"

}

#update_image
Update_xrayr() {
  cd ${cur_dir}
  echo "Tải hình ảnh DOCKER"
  docker-compose pull
  echo "Bắt đầu chạy dịch vụ DOCKER"
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
  echo "Bắt đầu chạy dịch vụ DOKCER"
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
  echo "-----XrayR Aiko-----"
  echo "Địa chỉ dự án và tài liệu trợ giúp:  https://github.com/AikoCute/XrayR"
  echo "AikoCute Hột Me"
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
