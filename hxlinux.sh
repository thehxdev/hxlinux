#!/usr/bin/env bash

# Used for debugging the script
# set -xe

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
NC='\033[0m'

VERSION_REGEX="(\d+\.)?(\d+\.)?(\*|\d+)"
CPU_ARCH=$(uname -m)

BANNER='
██╗  ██╗██╗  ██╗    ██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗
██║  ██║╚██╗██╔╝    ██║     ██║████╗  ██║██║   ██║╚██╗██╔╝
███████║ ╚███╔╝     ██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝ 
██╔══██║ ██╔██╗     ██║     ██║██║╚██╗██║██║   ██║ ██╔██╗ 
██║  ██║██╔╝ ██╗    ███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗
╚═╝  ╚═╝╚═╝  ╚═╝    ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝

=> by thehxdev
=> https://github.com/thehxdev/hxlinux
'


function log_error() {
	echo -e "${RED}[ERROR]" "$@" "${NC}"
}

function log_info() {
	echo -e "${GREEN}[INFO]" "$@" "${NC}"
}

function log_warn() {
	echo -e "${YELLOW}[WARN]" "$@" "${NC}"
}

function install_pkgs() {
	apt-get install $@ -y
	if [[ $? != 0 ]]; then
		log_error "failed to install ($@) packages"
	fi
}

function install_dependencies() {
	local commands
	local to_install

	commands=($@)
	to_install=()

	log_info "checking needed commands"
	for cmd in ${commands[@]}; do
		if ! command -v $cmd &>/dev/null; then
			to_install+=($cmd)
		fi
	done

	if [[ ${#to_install[@]} > 0 ]]; then
		log_info "installing missing commands (${to_install[@]})"
		install_pkgs ${to_install[@]}
	fi
}

function install_xcaddy() {
	local go_cmd

	go_cmd="/usr/local/go/bin/go"
	if [[ ! -e "$go_cmd" ]]; then
		install_golang
	fi

	$go_cmd install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
	if [[ $? != 0 ]]; then
		log_error "failed to install xcaddy"
		exit 1
	fi

	source "$($go_cmd env)"
	log_info "installed xcaddy to $GOPATH/xcaddy"
}

function install_caddy() {
	# From official installation docs
	# https://caddyserver.com/docs/install#debian-ubuntu-raspbian

	install_pkgs debian-keyring debian-archive-keyring apt-transport-https

	curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
	curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list

	apt-get update
	install_pkgs caddy
}

function install_xui() {
	# Use official script to install x-ui panel
	bash <(curl -Ls https://raw.githubusercontent.com/alireza0/x-ui/master/install.sh)
	exit $?
}

function install_xray_core() {
	# Use official script to install Xray-Core
	bash -c "$(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
	exit $?
}

function install_singbox_core() {
	# Use official script to install sing-box
	bash <(curl -fsSL https://sing-box.app/deb-install.sh)
	exit $?
}

function install_hysteria2() {
	# Use official script to install hysteria2
	bash <(curl -fsSL https://get.hy2.sh/)
	exit $?
}

function install_acme_script() {
	local dependencies

	dependencies=(socat)
	install_dependencies ${dependencies[@]}

	bash <(curl -fsSL https://get.acme.sh)
	if [[ $? != 0 ]]; then
		log_error "failed to install acme script"
		log_error "installed dependencies for acme: ${dependencies[@]}"
		exit 1
	fi

	local acme_path
	acme_path="/root/.acme.sh/acme.sh"

	$acme_path --set-default-ca --server letsencrypt
}

function install_dev_packages() {
	install_pkgs build-essential python3-full python3-pip python3-virtualenv
	log_info "installed development packages"
}

function install_golang() {
	local go_version
	local file_name
	local tmpdir

	tmpdir=$(mktemp -d)
	trap "rm -rf $tmpdir" EXIT

	# get latest version number from github tags
	go_version=$(curl -s 'https://github.com/golang/go/tags' | grep -Po "go$VERSION_REGEX" | sort -r | head -1)
	log_info "Golang latest version: $go_version"

	case "$CPU_ARCH" in
		x86_64)
			file_name="$go_version.linux-amd64.tar.gz"
			;;
		aarch64|arm64)
			file_name="$go_version.linux-arm64.tar.gz"
			;;
		*)
			log_error "unsupported cpu architecture ($CPU_ARCH)"
			exit 1
			;;
	esac

	log_info "downloading archive file to $tmpdir/$file_name"
	curl -LSf -o "$tmpdir/$file_name" "https://go.dev/dl/$file_name"
	if [[ $? != 0 ]]; then
		log_error "failed to download Golang compiler"
		return
	fi

	local install_path
	install_path="/usr/local"

	rm -rf "$install_path/go"
	tar -C $install_path -xzf "$tmpdir/$file_name"
	log_info "installed go on $install_path/go"
	log_info "dont forget to add $install_path/go/bin to your PATH environment variable"
}

function server_menu() {
	clear
	echo -e "${GREEN}1. Install Xray-Core${NC}"
	echo -e "${GREEN}2. Install Sing-Box${NC}"
	echo -e "${GREEN}3. Install Hysteria2${NC}"
	echo -e "${GREEN}4. Install ACME Script${NC}"
	echo -e "${GREEN}5. Install X-UI Panel${NC}"
	echo -e "${GREEN}6. Install caddy${NC}"
	echo -e "${GREEN}7. Install xcaddy${NC}"
	echo -e "${GREEN}8. Main Menu${NC}"
	echo -e "${YELLOW}9. Exit${NC}"

	read -rp "Enter an Option: " menu_option
	case $menu_option in
		1)
			install_xray_core
			;;
		2)
			install_singbox_core
			;;
		3)
			install_hysteria2
			;;
		4)
			install_acme_script
			;;
		5)
			install_xui
			;;
		6)
			install_caddy
			;;
		7)
			install_xcaddy
			;;
		8)
			main_menu
			;;
		9)
			exit 0
			;;
		*)
			log_error "Invalid Option. Run script again!"
			exit 1
			;;
	esac
}

function desktop_menu() {
	clear
}

function dev_menu() {
	clear
	echo -e "${GREEN}1. Install Development Packages${NC}"
	echo -e "${GREEN}2. Install Golang${NC}"
	echo -e "${GREEN}3. Main Menu${NC}"
	echo -e "${YELLOW}4. Exit${NC}"

	read -rp "Enter an Option: " menu_option
	case $menu_option in
		1)
			install_dev_packages
			;;
		2)
			install_golang
			;;
		3)
			main_menu
			;;
		4)
			exit 0
			;;
		*)
			log_error "Invalid Option. Run script again!"
			exit 1
			;;
	esac
}

function main_menu() {
	clear
	echo -e "$BANNER"
	echo -e "${GREEN}1. Server Menu${NC}"
	echo -e "${GREEN}2. Desktop Menu${NC}"
	echo -e "${GREEN}3. Dev Menu${NC}"
	echo -e "${YELLOW}4. Exit${NC}\n"

	read -rp "Enter an Option: " menu_option
	case $menu_option in
		1)
			server_menu
			;;
		2)
			# desktop_menu
			# TODO: desktop menu
			log_warn "not implemented"
			exit 1
			;;
		3)
			dev_menu
			;;
		4)
			exit 0
			;;
		*)
			log_error "Invalid Option. Run script again!"
			exit 1
			;;
	esac
}

function main() {
	if ! command -v apt-get &>/dev/null; then
		log_error 'this script only works for debian based distros'
		exit 1
	fi

	if [[ $UID != 0 ]]; then
		log_error 'run the script as root user'
		exit 1
	fi

	base_dependencies=(git unzip)
	install_dependencies ${base_dependencies[@]}

	main_menu
}

main
