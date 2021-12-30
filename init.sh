#!/bin/bash


echo -e "\033[33m****************************************************系统初始化开始***************************************************\033[0m"

echo -e "\033[33m****************************************************开始更新系统***************************************************\033[0m"
yum update -y 

yum install ntp -y 


DATE=`date +"%y-%m-%d %H:%M:%S"`

ntpserver1="ntp.aliyun.com"
ntpserver2="ntp1.aliyun.com"

[ $(id -u) -gt 0 ] && echo "请用root用户执行此脚本！" && exit 1

[ -f /tmp/init_error.log ] || touch /tmp/install_error.log

echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>$DATE 系统初始化报错记录<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<" >> /tmp/init_error.log

echo "hell"



menu(){
clear
echo "=================================================================================="
echo '                                  Linux 系统初始化完成                            '   
echo "=================================================================================="
cat << EOF
|-----------System Infomation---------------------------------------------------
| DATE         :$DATE
| HOSTNAME     :$HOSTNAME
| IP           :$IPADDR
--------------------------------------------------------------------------------
EOF
}

initSysctl(){
  echo ""
  echo -e "\033[33m*****************************************************优化内核参数****************************************************\033[0m"
cat >>/etc/sysctl.conf<<EOF
#保持在FIN-WAIT-2状态的时间，使系统可以处理更多连接。此参数值为整数，单位为秒。
net.ipv4.tcp_fin_timeout = 2
#开启重用，允许将TIME_WAIT socket用于新的TCP连接。默认为0，表示关闭。
net.ipv4.tcp_tw_reuse = 1
#开启TCP连接中TIME_WAIT socket的快速回收。默认值为0，表示关闭。
net.ipv4.tcp_tw_recycle = 1
#新建TCP连接请求，需要发送一个SYN包，该值决定内核需要尝试发送多少次syn连接请求才决定放弃建立连接。默认值是5. 对于高负责且通信良好的物理网络而言，调整为2
net.ipv4.tcp_syn_retries = 2
#对于远端SYN连接请求，内核会发送SYN+ACK数据包来确认收到了上一个SYN连接请求包，然后等待远端的确认(ack数据包）。该值则指定了内核会向远端发送tcp_synack_retires次SYN+ACK数据包。默认设定值是5，可以调整为2
net.ipv4.tcp_synack_retries = 2
#开启SYN cookie，出现SYN等待队列溢出时启用cookie处理，防范少量的SYN攻击。默认为0，表示关闭。
net.ipv4.tcp_syncookies = 1
#表示SYN队列的长度，预设为1024，这里设置队列长度为262 144，以容纳更多等待连接
net.ipv4.tcp_max_syn_backlog = 262144
#系统同时保持TIME_WAIT套接字的最大数量，如果超过这个数值将立刻被清楚并输出警告信息。默认值为180000。对于squid来说效果不是很大，但可以控制TIME_WAIT套接字最大值，避免squid服务器被拖死。
net.ipv4.tcp_max_tw_buckets = 5000
#表示系统中最多有多少TCP套接字不被关联到任何一个用户文件句柄上。如果超过这里设置的数字，连接就会复位并输出警告信息。这个限制仅仅是为了防止简单的DoS攻击。此值不能太小。
net.ipv4.tcp_max_orphans = 16384
# 增加TCP最大缓冲区大小
net.ipv4.tcp_rmem=4096 87380 4194304
net.ipv4.tcp_wmem=4096 16384 4194304
#keepalived启用时TCP发送keepalived消息的拼度。默认2小时。
net.ipv4.tcp_keepalive_time = 600 
#TCP发送keepalive探测以确定该连接已经断开的次数。根据情形也可以适当地缩短此值
net.ipv4.tcp_keepalive_probes = 5 
#探测消息发送的频率，乘以tcp_keepalive_probes就得到对于从开始探测以来没有响应的连接杀除的时间。默认值为75秒，也就是没有活动的连接将在大约11分钟以后将被丢弃。对于普通应用来说,这个值有一些偏大,可以根据需要改小.特别是web类服务器需要改小该值。
net.ipv4.tcp_keepalive_intvl = 15 
net.ipv4.route.gc_timeout = 100
#指定外部连接的端口范围。默认值为32768 61000
net.ipv4.ip_local_port_range = 1024 65000 
#定义了系统中每一个端口最大的监听队列的长度, 对于一个经常处理新连接的高负载 web服务环境来说，默认值为128，偏小
net.core.somaxconn = 16384 
#表示当在每个网络接口接收数据包的速率比内核处理这些包的速率快时，允许发送到队列的数据包的最大数量。
net.core.netdev_max_backlog = 16384
#避免放大攻击
net.ipv4.icmp_echo_ignore_broadcasts=1

vm.max_map_count = 262144

EOF

  sysctl  -p
  echo -e "\033[33m*****************************************************内核优化完成****************************************************\033[0m"
  echo ""
  sleep 1
}

initNofile(){
  echo ""
  echo -e "\033[33m****************************************************加大文件描述符***************************************************\033[0m"
cat >> /etc/security/limits.conf << EOF
*   soft    nofile  65535
*   hard    nofile  65535
*   soft    nproc   65535
*   hard    nproc   65535
EOF
}

initFirewall(){
  echo ""
  echo -e "\033[33m*************************************************禁用selinux和防火墙*************************************************\033[0m"
  \cp /etc/selinux/config /etc/selinux/config.$(date +%F)
  systemctl stop firewalld && systemctl disable firewalld
  sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
  setenforce 0
  systemctl status firewalld
  grep SELINUX=disabled /etc/selinux/config 
  echo -e "\033[33m************************************************完成禁用selinux和防火墙**********************************************\033[0m"
  echo ""
  sleep 2
}

initHistory(){
  echo ""
  echo -e "\033[33m*******************************************设置默认历史记录数和登录超时**********************************************\033[0m"
  
cat >> /etc/profile << EOF
export TMOUT=300
history
USER=`whoami`
USER_IP=`who -u am i 2>/dev/null| awk '{print $NF}'|sed -e 's/[()]//g'`
if [ "$USER_IP" = "" ]; then
    USER_IP=`hostname`
fi
if [ ! -d /var/log/history ]; then
    mkdir /var/log/history
    chmod 733 /var/log/history
fi
if [ ! -d /var/log/history/${LOGNAME} ]; then
    mkdir /var/log/history/${LOGNAME}
    chmod 300 /var/log/history/${LOGNAME}
fi
export HISTSIZE=1000
DT=`date +"%Y%m%d_%H:%M:%S"`
export HISTFILE="/var/log/history/${LOGNAME}/${USER}@${USER_IP}_$DT"
chmod 600 /var/log/history/${LOGNAME}/* 2>/dev/null
EOF

  source /etc/profile
  cat /etc/profile | grep -E 'HIST*|TMOUT' 
  echo -e "\033[33m**********************************完成设置默认历史记录数3000和登录超时时间600s***************************************\033[0m"
  echo ""
  sleep 1
}

initSsh(){
  echo ""
  echo -e "\033[33m************************************禁用GSSAPI认证和DNS反向解析，加快SSH登陆速度*************************************\033[0m"
  sed -i 's/^GSSAPIAuthentication yes$/GSSAPIAuthentication no/' /etc/ssh/sshd_config
  sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
  systemctl restart sshd
  systemctl status sshd 
  echo -e "\033[33m***********************************************完成ssh优化***********************************************************\033[0m"
  echo ""
  sleep 1
}


initTime(){
  echo ""
  echo -e "\033[33m*****************************************************配置时间同步****************************************************\033[0m"

  ping -c 4 $ntpserver1 2>/dev/null 
  timedatectl set-timezone Asia/Shanghai
  if [ $? -eq 0 ];then
	  ntpserver=`grep $ntpserver1 /etc/ntp.conf 2>/dev/null | wc -l `
	  if [ $ntpserver -eq 0 ];then
	  \cp /etc/ntp.conf  /etc/ntp.conf_$(date +%F)
cat >> /etc/ntp.conf <<EOF
#times sync by hwb at $(date +%F)
server $ntpserver1
server $ntpserver2
EOF
      systemctl restart ntpd
	  systemctl enable ntpd
	  systemctl status ntpd
	  ntpq -p
	  hwclock --systohc  #同步到硬件
	
      else
	    systemctl restart ntpd
	    systemctl enable ntpd
	    systemctl status ntpd
	    ntpq -p
	    hwclock --systohc  #同步到硬件 
	  fi
	else
	  echo "时间同步配置失败，请检查ntp服务是否正常" >> /tmp/install_error.log
  fi   
  echo -e "\033[33m***************************************************完成时间同步配置**************************************************\033[0m"
  echo ""
  sleep 2
}


main(){
initSysctl
initFirewall
initNofile
initHistory
initSsh
initTime
menu

    
}



main "$@"



#关闭不必要的服务
systemctl stop  postfix  && systemctl disable  postfix 


systemctl stop NetworkManager.service  && systemctl disable NetworkManager.service










