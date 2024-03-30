#!/bin/sh

dotnetDir="/opt/dotnet"
versions="12.1-zh0.1"

if [ -d "/etc/dns/config" ]
then
	dnsDir="/etc/dns"
else
    dnsDir="/opt/technitium/dns"
fi

dnsTar="$dnsDir/DnsServerPortable.tar.gz"
dnsUrl="https://gitee.com/Scattered_leaves/TechnitiumDnsServer-Chinese/releases/$versions/DnsServerPortable.tar.gz"

mkdir -p $dnsDir
installLog="$dnsDir/install.log"
echo "" > $installLog

echo ""
echo "============================="
echo "Technitium DNS Server 安装脚本"
echo "============================="

if dotnet --list-runtimes 2> /dev/null | grep -q "Microsoft.AspNetCore.App 8.0."; 
then
	dotnetFound="yes"
else
	dotnetFound="no"
fi

if [ ! -d $dotnetDir ] && [ "$dotnetFound" = "yes" ]
then
	echo ""
	echo "ASP.NET Core 运行时已安装"
else
	echo ""

	if [ -d $dotnetDir ] && [ "$dotnetFound" = "yes" ]
	then
		dotnetUpdate="yes"
		echo "正在更新 ASP.NET Core 运行时..."
	else
		dotnetUpdate="no"
		echo "正在安装 ASP.NET Core 运行时..."
	fi

	curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin -c 8.0 --runtime aspnetcore --no-path --install-dir $dotnetDir --verbose >> $installLog 2>&1

	if [ ! -f "/usr/bin/dotnet" ]
	then
		ln -s $dotnetDir/dotnet /usr/bin >> $installLog 2>&1
	fi

	if dotnet --list-runtimes 2> /dev/null | grep -q "Microsoft.AspNetCore.App 8.0."; 
	then
		if [ "$dotnetUpdate" = "yes" ]
		then
			echo "ASP.NET Core 运行时 更新成功!"
		else
			echo "ASP.NET Core 运行时 安装成功!"
		fi
	else
		echo "安装 ASP.NET Core 运行时 失败. 请重试"
		exit 1
	fi
fi

echo ""
echo "下载 Technitium DNS Server中..."

if curl -o $dnsTar --fail $dnsUrl >> $installLog 2>&1
then
	if [ -d $dnsDir ]
	then
		echo "更新 Technitium DNS Server..."
	else
		echo "安装 Technitium DNS Server..."
	fi
	
	tar -zxf $dnsTar -C $dnsDir >> $installLog 2>&1
	
	if [ "$(ps --no-headers -o comm 1 | tr -d '\n')" = "systemd" ] 
	then
		if [ -f "/etc/systemd/system/dns.service" ]
		then
			echo "重启systemd服务…"
			systemctl restart dns.service >> $installLog 2>&1
		else
			echo "配置systemd服务…"
			cp $dnsDir/systemd.service /etc/systemd/system/dns.service
			systemctl enable dns.service >> $installLog 2>&1
			
			systemctl stop systemd-resolved >> $installLog 2>&1
			systemctl disable systemd-resolved >> $installLog 2>&1
			
			systemctl start dns.service >> $installLog 2>&1
			
			rm /etc/resolv.conf >> $installLog 2>&1
			echo "nameserver 127.0.0.1" > /etc/resolv.conf 2>> $installLog
			
			if [ -f "/etc/NetworkManager/NetworkManager.conf" ]
			then
				echo "[main]" >> /etc/NetworkManager/NetworkManager.conf
				echo "dns=default" >> /etc/NetworkManager/NetworkManager.conf
			fi
		fi
	
		echo ""
		echo "Technitium DNS Server 安装成功!"
		echo "打开 http://$(hostname):5380/ 就可以访问Web控制面板."
		echo ""
		echo "Donate! Make a contribution by becoming a Patron: https://www.patreon.com/technitium"
		echo ""
	else
		echo ""
		echo "安装 Technitium DNS Server 失败: 未检测到systemd服务"
		exit 1
	fi
else
	echo ""
	echo "从 $dnsUrl 下载 Technitium DNS Server 失败"
	exit 1
fi
