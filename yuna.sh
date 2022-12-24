red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
purple(){
    echo -e "\033[35m\033[01m$1\033[0m"
}

# cài đặt docker 1
function aapanelgoc(){
cd /home
curl -sO https://raw.githubusercontent.com/HasumikiYuna/docker_v2/main/docker.sh && bash docker.sh
red "đã cài đặt hoàn tất mời quý zị dùng luôn cho nóng>.<"
}

# cài đặt bản aapanel bản tàu khựa
function aapanelTQ(){  
yum install -y wget && wget -O install.sh http://download.bt.cn/install/install_6.0.sh && sh install.sh
red "đang cài bản tàu khựa"
}

# bẻ khoá aapanel bản hiện tại
function panelcrack(){  
bash <(curl -Ls https://raw.githubusercontent.com/AZZ-vopp/Z_OV/main/script/Z_OVpanel.sh)
red "đã crack xong vui lòng f5 hoặc login lại aapanel"
}
# mở chặn speedtest
function unspeedtest(){
iptables -F && clear && echo "   đã mở khoá cho test speed khi dùng vpn !"

}
