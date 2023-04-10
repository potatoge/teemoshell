#!/bin/bash

# Author: teemossh
# Created: 2023-04-10
# Description: 一键Acme申请证书脚本

INFO="
             使用须知 ！！！
==========================================================
 
1.)请切换到 root 用户
2.)请确认你已经进行了域名解析
3.)关闭小云朵
4.)请确保该域名未申请过证书！！！

5.)使用过程中，有任何问题请联系 tg：@teemossh
========================================================== "

echo "$INFO"


read -p "是否要继续使用？[y/n]" choice

case "$choice" in
  y|Y )
    # 如果用户输入的是 y 或 Y，则继续执行脚本
    echo "继续使用脚本"
    # 在这里写下一步操作
    ;;
  n|N )
    # 如果用户输入的是 n 或 N，则退出脚本
    echo "退出脚本"
    # 在这里写退出操作，比如删除中间文件等
    exit 0
    ;;
  * )
    # 如果用户输入的既不是 y/Y，也不是 n/N，则提示用户输入错误，重新运行脚本
    echo "输入错误，请选择 y 或者 n"
    exit 1
    ;;
esac

# 读取系统类型信息

if [ $(id -u) != "0" ];then
    echo "Error: 此脚本必须以root身份运行!"
    exit 1
fi
source /etc/os-release
# 判断系统类型是否为Ubuntu或CentOS
if [ "$ID" == "centos" ]; then   
    # 使用yum更新包
    yum update -y && yum install -y curl socat bind-utils
    # 配置防火墙
    iptables -I INPUT -p tcp --dport 80 -j ACCEPT
    
else
    # 使用apt更新包
    apt update && apt upgrade -y
    # 安装curl
    apt install -y curl socat ufw dnsutils && ufw allow 80
    
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
echo "正在进行下一步操作......"


# 安装 acme.sh
curl https://get.acme.sh | sh
source ~/.bashrc

# 切换 CA 机构
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

# 输入您的域名并申请证书
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone

# 安装证书
~/.acme.sh/acme.sh --installcert -d $DOMAIN --key-file /etc/ssl/private.key --fullchain-file /etc/ssl/cert.crt


if [ -f /etc/ssl/private.key ]; then
  # 打印证书路径
        echo "申请证书完成！"
        echo "私钥路径: /etc/ssl/private.key"
        echo "公钥路径: /etc/ssl/cert.crt"
else
  echo "申请证书失败"
fi

sleep 10s && rm -f -- "$0"