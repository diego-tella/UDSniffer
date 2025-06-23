#!/bin/bash

#global variables
called=0

docker_sock_path="/var/run/docker.sock"  #change it if needed
docker_sock_changed="${docker_sock_path}.real"

mysqld_sock_path="/var/run/mysqld/mysqld.sock"
mysqld_sock_changed="${mysqld_sock_path}.real"


banner() {
cat << "EOF"
  _    _ _____   _____       _  __  __          
 | |  | |  __ \ / ____|     (_)/ _|/ _|         
 | |  | | |  | | (___  _ __  _| |_| |_ ___ _ __ 
 | |  | | |  | |\___ \| '_ \| |  _|  _/ _ \ '__|
 | |__| | |__| |____) | | | | | | | ||  __/ |   
  \____/|_____/|_____/|_| |_|_|_| |_| \___|_|   
                                                
                                                
EOF
}

check_socat() {
    if ! command -v socat >/dev/null 2>&1; then
        echo "[+] Error: socat is not installed. Wanna install? [Y/n]"
        read -r answer
        if [[ "$answer" =~ ^[Yy]$ || -z "$answer" ]]; then
            echo "[+] Attempting to install socat..."

            if command -v apt >/dev/null 2>&1; then
                sudo apt update && sudo apt install -y socat
            elif command -v yum >/dev/null 2>&1; then
                sudo yum install -y socat
            elif command -v pacman >/dev/null 2>&1; then
                sudo pacman -Sy socat
            else
                echo "[-] No supported package manager found. Please install socat manually."
                exit 1
            fi

            if ! command -v socat >/dev/null 2>&1; then
                echo "[-] socat installation failed or not found in PATH."
                exit 1
            fi
        else
            echo "[-] socat is required. Exiting."
            exit 1
        fi
    fi
}

exit() {
	if [[ called -eq 1 ]] ; then
		kill $(jobs -p) 2>/dev/null
		echo "[+] Exiting program... Returning original files"
		#back docker to original
		mv "$docker_sock_changed" "$docker_sock_path"
		mv "$mysqld_sock_changed" "$mysqld_sock_path"
	fi
}

help_menu() {
	echo "[+] You can run UDSniffer by passing the service you want to sniff"
    echo "Example: ./UDSniffer.sh docker"
    echo "Supported services so far: docker, mysql, all"
}

sniff_docker() {
	called=1
	mv "$docker_sock_path" "$docker_sock_changed"
	echo "[+] Starting socat to intercept Docker communication..."
	socat -v UNIX-LISTEN:"$docker_sock_path",fork UNIX-CONNECT:"$docker_sock_changed"

}

sniff_mysqld() {
	called=1
	mv "$mysqld_sock_path" "$mysqld_sock_changed"
	echo "[+] Starting socat to intercept mysqld communication..."
	socat -v UNIX-LISTEN:"$mysqld_sock_path",fork UNIX-CONNECT:"$mysqld_sock_changed"

}

banner
check_socat


trap exit SIGINT

case "$1" in
    docker)
        sniff_docker
        ;;
    mysql)
    		sniff_mysqld
    		;;
    all)
    		sniff_docker &
    		sniff_mysqld &
    		wait
    		;;
	  *)
         help_menu
          exit 1
          ;;
esac
