#! /usr/bin/env bash

# Script réaliser par Damien BRIAND
# INFRES 1A DL
# Et en toute honnêteté, avec un peux d'aide d'IA

set -euo pipefail

c0=$(tput sgr0)
myself=$(basename "$0")

# Configuration par défaut
distribution="debian"
release="trixie"
architecture="amd64"
username="user"
password=""
keyserver="hkp://keyserver.ubuntu.com"

# Fonctions Utilitaire
msg() {
	[ -n "${2-}" ] && tput setaf "$2"
	printf "%s%s\n" "$1" "$c0"
}

error() {
	msg "Erreur: $1" 9
	[ -z "${2-}" ] || exit "$2"
}

usage() {
	cat <<- EOF
		Usage: $myself -n NOM [-u USER] [-p PASS] [-d DISTRO] [-r RELEASE] [-a ARCH] [-h]
		Où:
		    -n, --name         : nom du conteneur (obligatoire)
		    -u, --user         : nom de l'utilisateur à créer (défaut: user)
		    -p, --password     : mot de passe de l'utilisateur (demandé si non fourni)
		    -d, --distribution : distribution à installer (défaut: debian)
		    -r, --release      : version de la distribution (défaut: trixie)
		    -a, --architecture : architecture du conteneur (défaut: amd64)
		    -h, --help         : affiche cette aide
	EOF
}

# Gestion des options
opts=$(getopt -o n:u:p:d:r:a:h --long name:,user:,password:,distribution:,release:,architecture:,help -n "$myself" -- "$@") \
	|| error "getopt failed with error code: $?" 1
eval set -- "$opts"

ct_name=""

while true; do
	case "$1" in
		-n|--name) ct_name="$2"; shift 2 ;;
		-u|--user) username="$2"; shift 2 ;;
		-p|--password) password="$2"; shift 2 ;;
		-d|--distribution) distribution="$2"; shift 2 ;;
		-r|--release) release="$2"; shift 2 ;;
		-a|--architecture) architecture="$2"; shift 2 ;;
		-h|--help) usage; exit 0 ;;
		--) shift; break ;;
		*) break ;;
	esac
done

# Vérifications
[ -n "$ct_name" ] || { usage; error "Le nom du conteneur est obligatoire (-n)" 1; }
[ "$(id -u)" -eq 0 ] || error "Ce script doit être exécuté en root (sudo)" 2
[ -x "$(which lxc-create)" ] || error "LXC n'est pas installé. Essayez: sudo apt install lxc" 3

# Demande du mot de passe si non fourni
if [ -z "$password" ]; then
	read -r -s -p "Mot de passe pour l'utilisateur '$username': " password
	printf "\n"
	read -r -s -p "Confirmez le mot de passe: " password_confirm
	printf "\n"
	[ "$password" = "$password_confirm" ] || error "Les mots de passe ne correspondent pas" 4
fi

# Vérifier si le conteneur existe déjà
if lxc-ls | grep -qw "$ct_name"; then
	error "Le conteneur '$ct_name' existe déjà" 5
fi

msg "=== Création du conteneur '$ct_name' ===" 11
lxc-create -t download -n "$ct_name" -- \
	-d "$distribution" \
	-r "$release" \
	-a "$architecture"

msg "=== Démarrage du conteneur ===" 11
lxc-start -n "$ct_name"

msg "Attente du démarrage du conteneur..." 10
sleep 3

msg "=== Configuration du conteneur ===" 11

# Script d'initialisation exécuté dans le conteneur
lxc-attach -n "$ct_name" -- bash -c "
	export PATH=\"\$PATH:/sbin:/usr/sbin\"
	export DEBIAN_FRONTEND=noninteractive

	# Génération de la locale fr_FR.UTF-8
	echo 'fr_FR.UTF-8 UTF-8' >> /etc/locale.gen
	locale-gen
	update-locale LANG=fr_FR.UTF-8

	# Mise à jour et installation des paquets
	apt update
	apt install -y ssh sudo

	# Création de l'utilisateur
	useradd -m -s /bin/bash '$username'
	echo '$username:$password' | chpasswd

	# Ajout au groupe sudo
	usermod -aG sudo '$username'
"

msg "=== Conteneur '$ct_name' initialisé avec succès ===" 10
msg "Utilisateur: $username" 11

# Affichage des informations du conteneur
ct_ip=$(lxc-ls -f | grep "^$ct_name " | awk '{print $5}')
msg "Adresse IP: $ct_ip" 11
msg "Connexion SSH: ssh $username@$ct_ip" 11

exit 0
