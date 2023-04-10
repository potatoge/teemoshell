#!/bin/bash
clear
INFO="
                    ! ! !使用须知 ！！！                   
===========================================================

  1.)请切换到 root 用户
  2.)请确认你已经进行了域名解析
  3.)cloudflare关闭小云朵
  4.)请确保该域名未申请过证书！！！

  5.)出于安全考虑，安装x-ui面板强制要求修改用户名，密码，端口
  6.)使用过程中，有任何问题请联系 tg：@teemossh

==========================================================="

echo "$INFO"


# 提示用户选择继续或退出脚本
while :
do
  read -p "(输入 Y 继续，输入 N 取消) " CHOICE
  case "${CHOICE}" in
    Y|y)
      echo "您选择了继续操作。"
      break
      ;;
    N|n)
      echo "您选择了取消操作。"
      exit 0
      ;;
    *)
      echo "无效的选择，请重新输入。"
      ;;
  esac
done

echo "开始部署..."

# 安装常用软件
apt install wget curl sudo vim git socat cron lsof ufw net-tools -y >/dev/null

##解决vim中文乱码问题
# 配置文件路径
CONFIG_FILE="/etc/vim/vimrc.local"

# 写入配置指令
echo "set fileencodings=utf-8,ucs-bom,gb18030,gbk,gb2312,cp936" >> $CONFIG_FILE
echo "set encoding=utf-8" >> $CONFIG_FILE
echo "set termencoding=utf-8" >> $CONFIG_FILE
echo "set langmenu=zh_CN.UTF-8" >> $CONFIG_FILE

# 输出成功信息
echo "解决vin中文乱码配置写入完成"

# 启用 BBR TCP 拥塞控制算法
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf >/dev/null
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf >/dev/null
sysctl -p >/dev/null
echo "已启用 BBR TCP 拥塞控制算法..."

# 默认用户名和密码
DEFAULT_USERNAME="admin"
DEFAULT_PASSWORD="password"

echo "即将安装x-ui面板..."

echo "出于安全考虑，强制要求更改x-ui面板用户名，密码，端口(建议10000-65535)"
# 获取用户名
while :
do
  read -p "请输入您的用户名: " USERNAME
  if [[ -n "${USERNAME}" ]]; then
    break
  else
    echo "用户名不能为空，请重新输入。"
  fi
done

# 获取密码
while :
do
  read -p "请输入您的密码: " PASSWORD
  if [[ -n "${PASSWORD}" ]]; then
    break
  else
    echo "密码不能为空，请重新输入。"
  fi
done

# 获取端口
while :
do
  read -p "请输入要使用的端口: " PORT
  if [[ "${PORT}" =~ ^[0-9]+$ ]] && [[ "${PORT}" -le 65535 ]] && [[ -n "${PORT}" ]]; then
    break
  else
    echo "端口必须是数字且小于等于 65535，请重新输入。"
  fi
done

# 安装 x-ui 程序
bash <(curl -Ls https://raw.githubusercontent.com/vaxilu/x-ui/master/install.sh) <<EOF >/dev/null 2>&1
y
${USERNAME}
${PASSWORD}
${PORT}
EOF

# 输出安装结果
if [[ "${PORT}" == "54321" ]]; then
  echo "x-ui 已安装成功！"
  echo "用户名: ${USERNAME}"
  echo "密码: ${PASSWORD}"
else
  echo "x-ui 已安装成功！"
  echo "用户名: ${USERNAME}"
  echo "密码: ${PASSWORD}"
  echo "端口: ${PORT}"
fi

# 配置防火墙
ufw allow ${PORT}
ufw allow 80

# 读取系统类型信息

if [ $(id -u) != "0" ];then
    echo "Error: 此脚本必须以root身份运行!"
    exit 1
fi
source /etc/os-release
# 判断系统类型是否为Ubuntu或CentOS
if [ "$ID" == "centos" ]; then   
    # 使用yum更新包
    yum update -y && yum install -y curl socat wget bind-utils && yum update ca-certificates >/dev/null 2>&1
    # 配置防火墙
    iptables -I INPUT -p tcp --dport 80 -j ACCEPT
    
else
    # 使用apt更新包
    apt update && apt upgrade -y >/dev/null 2>&1
    # 安装curl
    apt install -y curl socat wget ufw dnsutils ca-certificates >/dev/null 2>&1
    
fi


# 获取 VPS IP 地址
VPS_IP=$(curl -4 ifconfig.co -s)

while true
do
  # 获取用户输入的域名
  read -p "请输入您的域名：" DOMAIN
  
  # 获取该域名解析的IP地址
  DOMAIN_IP=$(nslookup $DOMAIN | awk '/^Address: /{print $2}')
  
  # 判断该域名的IP是否等于VPS的IP
  if [ $DOMAIN_IP = $VPS_IP ]
  then
    echo "$DOMAIN 域名已经解析到 VPS 的 IP 地址，可以继续下一步操作。"
    break
  else
    read -p "$DOMAIN 域名未解析到 VPS 的 IP 地址，是否重新输入域名？[y/n]：" RES
    case $RES in
      y|Y) continue
        ;;
      n|N) echo "已退出脚本。"; exit
        ;;
      *) echo "错误的输入，请重新输入。"
        ;;
    esac
  fi
done

# 在这里可以继续写下一步操作的代码
echo "正在进行申请证书流程......"

read -p "请输入一个邮箱地址（例：teemo@gmail.com）：" EMAIL
# 安装 acme.sh
wget -O -  https://get.acme.sh | sh -s email=$EMAIL
source ~/.bashrc

# 切换 CA 机构
bash ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

# 输入您的域名并申请证书
bash ~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone

# 安装证书
bash ~/.acme.sh/acme.sh --installcert -d $DOMAIN --key-file /etc/ssl/private.key --fullchain-file /etc/ssl/cert.crt


if [ -f /etc/ssl/private.key ]; then
  # 打印证书路径
        echo "申请证书完成！"
        echo "私钥路径: /etc/ssl/private.key"
        echo "公钥路径: /etc/ssl/cert.crt"
else
  echo "申请证书失败"
fi

echo "已部署完成！"
echo "----------------------------------------------------"
echo "x-ui 配置信息如下："
echo "用户名：$USERNAME"
echo "密码：$PASSWORD"
echo "端口：$PORT"
echo "----------------------------------------------------"
echo " "
echo "公钥路径：/etc/ssl/cert.crt"
echo "私钥路径：/etc/ssl/private.key"
echo "请将以下证书路径粘贴到 x-ui 面板中的证书路径中："
echo " "
echo "----------------------------------------------------"
echo " "
echo "访问 http://<你的服务器 IP 或域名>:$PORT 进入 x-ui。"
echo " "
echo "----------------------------------------------------"


echo "======================================================="
echo " "
echo " "
echo "              即将进行vps基本安防配置...                 "
echo " "
echo "           ！！！小白请直接<回车>退出脚本！！！           "
echo "           ！！！小白请直接<回车>退出脚本！！！           "
echo " "
echo " "
echo "======================================================="
# 询问是否需要进行基本安防设置
ask_for_basic_security_setting() {
    read -p "是否执行Linux基本安防设置？(y/n，默认为n): " answer
    case ${answer} in
        [Yy])
            # 如果用户输入的是y或Y，则执行基本安防设置
            basic_security_setting
            ;;
        *)
            # 其它任何情况，则不执行，继续下一步操作
            echo "已跳过执行基本安防设置"
            ;;
    esac
}

# 执行Linux基本安防设置
basic_security_setting() {

    # 判断用户是否为root用户
    if [ "$EUID" -ne 0 ]; then
        echo "请以root用户或使用sudo执行该脚本"
        exit 1
    fi

    # 1.创建新用户并设置sudo权限
    read -p "是否需要创建新用户并设置sudo权限？(y/n，默认为n): " answer
    case ${answer} in
        [Yy])
            read -p "请输入您的用户名：" username
            read -s -p "请输入您的密码：" password
            echo
            adduser $username --gecos "First Last,RoomNumber,WorkPhone,HomePhone" --disabled-password
            echo "$username:$password" | chpasswd
            usermod -aG sudo $username
            if [ $? -eq 0 ]; then
                echo "${username}用户创建成功，并已获得sudo权限"
            else
                echo "创建用户失败，请重新尝试或手动创建用户"
            fi
            ;;
        *)
            echo "已跳过创建新用户并设置sudo权限"
            ;;
    esac

    # 2.更改SSH端口
    read -p "是否需要修改SSH默认端口号（22）？(y/n，默认为n): " answer
    case ${answer} in
        [Yy])
            read -p "请输入要修改的SSH端口号: " ssh_port
            sed -i "s/^.*Port 22/Port $ssh_port/" /etc/ssh/sshd_config
            systemctl restart sshd
            echo "SSH端口已更改为${ssh_port}"
            ;;
        *)
            echo "已跳过修改SSH端口号"
            ;;
    esac

    # 3.禁止ssh直接root登录
    read -p "是否需要禁止ssh直接root登录？(y/n，默认为n): " answer
    case ${answer} in
        [Yy])
            sed -i "s/^PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
            echo "禁止root直接登录SSH已成功生效"
            ;;
        *)
            echo "已跳过禁止ssh直接root登录"
            ;;
    esac

    echo "Linux基本安防设置完成！"
}

# 询问用户是否需要执行基本安防设置
read -p "是否需要执行Linux基本安防设置？(y/n，默认为n): " answer
case ${answer} in
    [Yy])
        # 如果用户输入的是y或Y，则执行基本安防设置
        basic_security_setting
        ;;
    *)
        # 其它任何情况，则不执行，直接退出脚本
        echo "脚本已退出"
        exit
        ;;
esac

sleep 10s && rm -f -- "$0"