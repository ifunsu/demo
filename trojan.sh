#!/bin/bash
function blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
function green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
function red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
function version_lt(){
    test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" != "$1"; 
}

source /etc/os-release
RELEASE=$ID
VERSION=$VERSION_ID
if [ "$RELEASE" == "centos" ]; then
    release="centos"
    systemPackage="yum"
elif [ "$RELEASE" == "debian" ]; then
    release="debian"
    systemPackage="apt-get"
elif [ "$RELEASE" == "ubuntu" ]; then
    release="ubuntu"
    systemPackage="apt-get"
fi
systempwd="/etc/systemd/system/"

function install_trojan(){
    $systemPackage install -y nginx
    if [ ! -d "/etc/nginx/" ]; then
        red "nginx installation error, please uninstall trojan and reinstall"
        exit 1
    fi
    cat > /etc/nginx/nginx.conf <<-EOF
user  root;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    #gzip  on;
    server {
        listen       80;
        server_name  $your_domain;
        root /usr/share/nginx/html;
        index index.php index.html index.htm;
    }
}
EOF
    systemctl restart nginx
    sleep 3
    rm -rf /usr/share/nginx/html/*
    cd /usr/share/nginx/html/
    wget https://github.com/atrandys/trojan/raw/master/fakesite.zip >/dev/null 2>&1
    unzip fakesite.zip >/dev/null 2>&1
    sleep 5
    if [ ! -d "/usr/src" ]; then
        mkdir /usr/src
    fi
    if [ ! -d "/usr/src/trojan-cert" ]; then
        mkdir /usr/src/trojan-cert /usr/src/trojan-temp
        mkdir /usr/src/trojan-cert/$your_domain
        if [ ! -d "/usr/src/trojan-cert/$your_domain" ]; then
            red "/usr/src/trojan-cert/$your_domain directory not found"
            exit 1
        fi
        curl https://get.acme.sh | sh
        ~/.acme.sh/acme.sh  --register-account  -m test@$your_domain --server zerossl
        ~/.acme.sh/acme.sh  --issue  -d $your_domain  --nginx
        if test -s /root/.acme.sh/$your_domain/fullchain.cer; then
            cert_success="1"
        fi
    elif [ -f "/usr/src/trojan-cert/$your_domain/fullchain.cer" ]; then
        cd /usr/src/trojan-cert/$your_domain
        create_time=`stat -c %Y fullchain.cer`
        now_time=`date +%s`
        minus=$(($now_time - $create_time ))
        if [  $minus -gt 5184000 ]; then
            curl https://get.acme.sh | sh
            ~/.acme.sh/acme.sh  --register-account  -m test@$your_domain --server zerossl
            ~/.acme.sh/acme.sh  --issue  -d $your_domain  --nginx
            if test -s /root/.acme.sh/$your_domain/fullchain.cer; then
                cert_success="1"
            fi
        else 
            green "Domain $your_domain certify exist and in 60 days, not need to request."
            cert_success="1"
        fi        
    else 
        mkdir /usr/src/trojan-cert/$your_domain
        curl https://get.acme.sh | sh
        ~/.acme.sh/acme.sh  --register-account  -m test@$your_domain --server zerossl
        ~/.acme.sh/acme.sh  --issue  -d $your_domain  --nginx
        if test -s /root/.acme.sh/$your_domain/fullchain.cer; then
            cert_success="1"
        fi
    fi
    
    if [ "$cert_success" == "1" ]; then
        cat > /etc/nginx/nginx.conf <<-EOF
user  root;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    #gzip  on;
    server {
        listen       127.0.0.1:80;
        server_name  $your_domain;
        root /usr/share/nginx/html;
        index index.php index.html index.htm;
    }
    server {
        listen       0.0.0.0:80;
        server_name  $your_domain;
        return 301 https://$your_domain\$request_uri;
    }
    
}
EOF
        systemctl restart nginx
        systemctl enable nginx
        cd /usr/src
        wget https://api.github.com/repos/trojan-gfw/trojan/releases/latest >/dev/null 2>&1
        latest_version=`grep tag_name latest| awk -F '[:,"v]' '{print $6}'`
        rm -f latest
        green "Begin download trojan amd64"
        wget https://github.com/trojan-gfw/trojan/releases/download/v${latest_version}/trojan-${latest_version}-linux-amd64.tar.xz
        tar xf trojan-${latest_version}-linux-amd64.tar.xz >/dev/null 2>&1
        rm -f trojan-${latest_version}-linux-amd64.tar.xz
        #下载trojan客户端
        green "Begin download and processing trojan windows client"
        wget https://github.com/atrandys/trojan/raw/master/trojan-cli.zip
        wget -P /usr/src/trojan-temp https://github.com/trojan-gfw/trojan/releases/download/v${latest_version}/trojan-${latest_version}-win.zip
        unzip -o trojan-cli.zip >/dev/null 2>&1
        unzip -o /usr/src/trojan-temp/trojan-${latest_version}-win.zip -d /usr/src/trojan-temp/ >/dev/null 2>&1
        mv -f /usr/src/trojan-temp/trojan/trojan.exe /usr/src/trojan-cli/
        green "Set trojan password"
        read -p "Enter password: " trojan_passwd
        #trojan_passwd=$(cat /dev/urandom | head -1 | md5sum | head -c 8)
        cat > /usr/src/trojan-cli/config.json <<-EOF
{
    "run_type": "client",
    "local_addr": "127.0.0.1",
    "local_port": 1080,
    "remote_addr": "$your_domain",
    "remote_port": 443,
    "password": [
        "$trojan_passwd"
    ],
    "log_level": 1,
    "ssl": {
        "verify": true,
        "verify_hostname": true,
        "cert": "",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
        "sni": "",
        "alpn": [
            "h2",
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "curves": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": false,
        "fast_open_qlen": 20
    }
}
EOF
         rm -rf /usr/src/trojan/server.conf
         cat > /usr/src/trojan/server.conf <<-EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "$trojan_passwd"
    ],
    "log_level": 1,
    "ssl": {
        "cert": "/usr/src/trojan-cert/$your_domain/fullchain.cer",
        "key": "/usr/src/trojan-cert/$your_domain/private.key",
        "key_password": "",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
        "prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": false,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": false,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": ""
    }
}
EOF
        cd /usr/src/trojan-cli/
        zip -q -r trojan-cli.zip /usr/src/trojan-cli/
        rm -rf /usr/src/trojan-temp/
        rm -f /usr/src/trojan-cli.zip
        trojan_path=$(cat /dev/urandom | head -1 | md5sum | head -c 16)
        #mkdir /usr/share/nginx/html/${trojan_path}
        #mv /usr/src/trojan-cli/trojan-cli.zip /usr/share/nginx/html/${trojan_path}/	
        cat > ${systempwd}trojan.service <<-EOF
[Unit]  
Description=trojan  
After=network.target  
   
[Service]  
Type=simple  
PIDFile=/usr/src/trojan/trojan/trojan.pid
ExecStart=/usr/src/trojan/trojan -c "/usr/src/trojan/server.conf"  
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=1s
   
[Install]  
WantedBy=multi-user.target
EOF

        chmod +x ${systempwd}trojan.service
        systemctl enable trojan.service
        cd /root
        ~/.acme.sh/acme.sh  --installcert  -d  $your_domain   \
            --key-file   /usr/src/trojan-cert/$your_domain/private.key \
            --fullchain-file  /usr/src/trojan-cert/$your_domain/fullchain.cer \
            --reloadcmd  "systemctl restart trojan"	
        green "==========================================================================="
        green "windows client path /usr/src/trojan-cli/trojan-cli.zip, all configuaration ready."
        green "==========================================================================="
        echo
        echo
        green "                          client configuaration"
        green "==========================================================================="
        cat /usr/src/trojan-cli/config.json
        green "==========================================================================="
    else
        red "==================================="
        red "https certiry not request error, fail installation."
        red "==================================="
    fi
}
function preinstall_check(){

    nginx_status=`ps -aux | grep "nginx: worker" |grep -v "grep"`
    if [ -n "$nginx_status" ]; then
        systemctl stop nginx
    fi
    $systemPackage -y install net-tools socat >/dev/null 2>&1
    Port80=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 80`
    Port443=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 443`
    if [ -n "$Port80" ]; then
        process80=`netstat -tlpn | awk -F '[: ]+' '$5=="80"{print $9}'`
        red "==========================================================="
        red "Port 80 error, process: ${process80}, faild to install."
        red "==========================================================="
        exit 1
    fi
    if [ -n "$Port443" ]; then
        process443=`netstat -tlpn | awk -F '[: ]+' '$5=="443"{print $9}'`
        red "============================================================="
        red "Port 80 error, process: ${process443}, faild to install."
        red "============================================================="
        exit 1
    fi
    if [ -f "/etc/selinux/config" ]; then
        CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
        if [ "$CHECK" == "SELINUX=enforcing" ]; then
            green "$(date +"%Y-%m-%d %H:%M:%S") - SELinux状态非disabled,关闭SELinux."
            setenforce 0
            sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
            #loggreen "SELinux is not disabled, add port 80/443 to SELinux rules."
            #loggreen "==== Install semanage"
            #logcmd "yum install -y policycoreutils-python"
            #semanage port -a -t http_port_t -p tcp 80
            #semanage port -a -t http_port_t -p tcp 443
            #semanage port -a -t http_port_t -p tcp 37212
            #semanage port -a -t http_port_t -p tcp 37213
        elif [ "$CHECK" == "SELINUX=permissive" ]; then
            green "$(date +"%Y-%m-%d %H:%M:%S") - SELinux status not disabled, close SELinux."
            setenforce 0
            sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
        fi
    fi
    if [ "$release" == "centos" ]; then
        if  [ -n "$(grep ' 6\.' /etc/redhat-release)" ] ;then
        red "==============="
        red "Not support current system"
        red "==============="
        exit
        fi
        if  [ -n "$(grep ' 5\.' /etc/redhat-release)" ] ;then
        red "==============="
        red "Not support current system"
        red "==============="
        exit
        fi
        firewall_status=`systemctl status firewalld | grep "Active: active"`
        if [ -n "$firewall_status" ]; then
            green "Firewalld enabled, add port 80/443."
            firewall-cmd --zone=public --add-port=80/tcp --permanent
            firewall-cmd --zone=public --add-port=443/tcp --permanent
            firewall-cmd --reload
        fi
        rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm --force --nodeps
    elif [ "$release" == "ubuntu" ]; then
        if  [ -n "$(grep ' 14\.' /etc/os-release)" ] ;then
        red "==============="
        red "Not support current system"
        red "==============="
        exit
        fi
        if  [ -n "$(grep ' 12\.' /etc/os-release)" ] ;then
        red "==============="
        red "Not support current system"
        red "==============="
        exit
        fi
        ufw_status=`systemctl status ufw | grep "Active: active"`
        if [ -n "$ufw_status" ]; then
            ufw allow 80/tcp
            ufw allow 443/tcp
            ufw reload
        fi
        apt-get update
    elif [ "$release" == "debian" ]; then
        ufw_status=`systemctl status ufw | grep "Active: active"`
        if [ -n "$ufw_status" ]; then
            ufw allow 80/tcp
            ufw allow 443/tcp
            ufw reload
        fi
        apt-get update
    fi
    $systemPackage -y install  wget unzip zip curl tar >/dev/null 2>&1
    green "======================="
    blue "Enter VPS domain"
    green "======================="
    read your_domain
    real_addr=`ping ${your_domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    local_addr=`curl ipv4.icanhazip.com`
    if [ $real_addr == $local_addr ] ; then
        green "=========================================="
        green "       domain good , begin to install trojan"
        green "=========================================="
        sleep 1s
        install_trojan
    else
        red "===================================="
        red "Domain not compactable to VPS IP"
        red "Continued?"
        red "===================================="
        read -p "Enter [Y/n] :" yn
        [ -z "${yn}" ] && yn="y"
        if [[ $yn == [Yy] ]]; then
            green "Keep running."
            sleep 1s
            install_trojan
        else
            exit 1
        fi
    fi
}

function repair_cert(){
    systemctl stop nginx
    #iptables -I INPUT -p tcp --dport 80 -j ACCEPT
    #iptables -I INPUT -p tcp --dport 443 -j ACCEPT
    Port80=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 80`
    if [ -n "$Port80" ]; then
        process80=`netstat -tlpn | awk -F '[: ]+' '$5=="80"{print $9}'`
        red "==========================================================="
        red "Port 80 used by ${process80}, faild to install."
        red "==========================================================="
        exit 1
    fi
    green "============================"
    blue "Enter domain name"
    blue "Same with previus"
    green "============================"
    read your_domain
    real_addr=`ping ${your_domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    local_addr=`curl ipv4.icanhazip.com`
    if [ $real_addr == $local_addr ] ; then
        ~/.acme.sh/acme.sh  --register-account  -m test@$your_domain --server zerossl
        ~/.acme.sh/acme.sh  --issue  -d $your_domain  --standalone
        ~/.acme.sh/acme.sh  --installcert  -d  $your_domain   \
            --key-file   /usr/src/trojan-cert/$your_domain/private.key \
            --fullchain-file /usr/src/trojan-cert/$your_domain/fullchain.cer \
            --reloadcmd  "systemctl restart trojan"
        if test -s /usr/src/trojan-cert/$your_domain/fullchain.cer; then
            green "Certify good"
            systemctl restart trojan
            systemctl start nginx
        else
            red "Certify faild"
        fi
    else
        red "================================"
        red "Domain name to ip is not same with VPS IP"
        red "Faild to install, make sure is's same."
        red "================================"
    fi
}

function remove_trojan(){
    red "================================"
    red "uninstall trojan"
    red "and uninstall nginx"
    red "================================"
    systemctl stop trojan
    systemctl disable trojan
    systemctl stop nginx
    systemctl disable nginx
    rm -f ${systempwd}trojan.service
    if [ "$release" == "centos" ]; then
        yum remove -y nginx
    else
        apt-get -y autoremove nginx
        apt-get -y --purge remove nginx
        apt-get -y autoremove && apt-get -y autoclean
        find / | grep nginx | sudo xargs rm -rf
    fi
    rm -rf /usr/src/trojan/
    rm -rf /usr/src/trojan-cli/
    rm -rf /usr/share/nginx/html/*
    rm -rf /etc/nginx/
    rm -rf /root/.acme.sh/
    green "=============="
    green "trojan uninstalled"
    green "=============="
}

function update_trojan(){
    /usr/src/trojan/trojan -v 2>trojan.tmp
    curr_version=`cat trojan.tmp | grep "trojan" | awk '{print $4}'`
    wget https://api.github.com/repos/trojan-gfw/trojan/releases/latest >/dev/null 2>&1
    latest_version=`grep tag_name latest| awk -F '[:,"v]' '{print $6}'`
    rm -f latest
    rm -f trojan.tmp
    if version_lt "$curr_version" "$latest_version"; then
        green "Current version $curr_version, lastest version$latest_version, upgrading……"
        mkdir trojan_update_temp && cd trojan_update_temp
        wget https://github.com/trojan-gfw/trojan/releases/download/v${latest_version}/trojan-${latest_version}-linux-amd64.tar.xz >/dev/null 2>&1
        tar xf trojan-${latest_version}-linux-amd64.tar.xz >/dev/null 2>&1
        mv ./trojan/trojan /usr/src/trojan/
        cd .. && rm -rf trojan_update_temp
        systemctl restart trojan
    /usr/src/trojan/trojan -v 2>trojan.tmp
    green "Server trojan upgrade completed , current version: `cat trojan.tmp | grep "trojan" | awk '{print $4}'`, please download latest version"
    rm -f trojan.tmp
    else
        green "Current version $curr_version, latest version $latest_version, not need to upgrade"
    fi
   
   
}

start_menu(){
    clear
    green " ======================================="
    green " 介绍: 一键安装trojan      "
    green " 系统: centos7+/debian9+/ubuntu16.04+"
    green " 作者: A             "
    blue " 注意:"
    red " *1. 不要在任何生产环境使用此脚本"
    red " *2. 不要占用80和443端口"
    red " *3. 若第二次使用脚本，请先执行卸载trojan"
    green " ======================================="
    echo
    green " 1. install trojan"
    red " 2. uninstall trojan"
    green " 3. upgrad trojan"
    green " 4. fix certification"
    blue " 0. exit"
    echo
    read -p "Enter: " num
    case "$num" in
    1)
    preinstall_check
    ;;
    2)
    remove_trojan 
    ;;
    3)
    update_trojan 
    ;;
    4)
    repair_cert 
    ;;
    0)
    exit 1
    ;;
    *)
    clear
    red "Enter number"
    sleep 1s
    start_menu
    ;;
    esac
}

start_menu
