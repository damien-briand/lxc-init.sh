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
interface="cli"

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
		Usage: $myself -n NOM [-u USER] [-p PASS] [-d DISTRO] [-r RELEASE] [-a ARCH] [-g] [-h]
		Où:
		    -n, --name         : nom du conteneur (obligatoire en mode CLI)
		    -u, --user         : nom de l'utilisateur à créer (défaut: user)
		    -p, --password     : mot de passe de l'utilisateur (demandé si non fourni)
		    -d, --distribution : distribution à installer (défaut: debian)
		    -r, --release      : version de la distribution (défaut: trixie)
		    -a, --architecture : architecture du conteneur (défaut: amd64)
		    -g, --graphique    : interface graphique avec zenity
		    -h, --help         : affiche cette aide		
	EOF
}


# Gestion des options
opts=$(getopt -o n:u:p:d:r:a:gh --long name:,user:,password:,distribution:,release:,architecture:,graphique,gui-create,help -n "$myself" -- "$@") \
	|| error "getopt failed with error code: $?" 1
eval set -- "$opts"

ct_name=""
gui_create_mode=false

while true; do
	case "$1" in
		-n|--name) ct_name="$2"; shift 2 ;;
		-u|--user) username="$2"; shift 2 ;;
		-p|--password) password="$2"; shift 2 ;;
		-d|--distribution) distribution="$2"; shift 2 ;;
		-r|--release) release="$2"; shift 2 ;;
		-a|--architecture) architecture="$2"; shift 2 ;;
		-g|--graphique) interface="gui"; shift ;;
		--gui-create) gui_create_mode=true; shift ;;
		-h|--help) usage; exit 0 ;;
		--) shift; break ;;
		*) break ;;
	esac
done

# Demande des droits sudo
msg "Demande des droits sudo" 10
sudo -k
sudo -v

# Vérifications
[ -n "$ct_name" ] || { usage; error "Le nom du conteneur est obligatoire (-n)" 1; }
[ -x "$(which lxc-create)" ] || error "LXC n'est pas installé. Essayez: sudo apt install lxc" 3


gui_interface() {
	# Vérification de zenity
	[ -x "$(which zenity)" ] || error "Zenity n'est pas installé. Essayez: sudo apt install zenity" 10

	# Demande du nom du conteneur
	ct_name=$(zenity --entry \
		--title="Nom du conteneur" \
		--text="Entrez le nom du conteneur:" \
		--entry-text="c1" \
		--width=400 2>/dev/null)
	[ -n "$ct_name" ] || { msg "Annulation." 9; exit 0; }

	# Vérifier si le conteneur existe déjà (nécessite sudo)
	if sudo lxc-ls 2>/dev/null | grep -qw "$ct_name"; then
		zenity --error --text="Le conteneur '$ct_name' existe déjà !" --width=300 2>/dev/null
		exit 5
	fi

	# Demande du nom d'utilisateur
	username=$(zenity --entry \
		--title="Nom d'utilisateur" \
		--text="Entrez le nom d'utilisateur:" \
		--entry-text="user" \
		--width=400 2>/dev/null)
	[ -n "$username" ] || { msg "Annulation." 9; exit 0; }

	# Demande du mot de passe
	password=$(zenity --password \
		--title="Mot de passe" \
		--text="Entrez le mot de passe pour l'utilisateur '$username':" \
		--width=400 2>/dev/null)
	[ -n "$password" ] || { msg "Annulation." 9; exit 0; }

	# Choix de la distribution
	distro_choice=$(zenity --list \
		--title="Distribution" \
		--text="Choisissez la distribution:" \
		--column="Distribution" --column="Version" --column="Architecture" \
		"debian" "trixie" "amd64" \
		"debian" "bookworm" "amd64" \
		"ubuntu" "noble" "amd64" \
		"ubuntu" "jammy" "amd64" \
		--width=500 --height=300 --hide-column=1 --print-column=1,2,3 2>/dev/null)
	
	if [ -n "$distro_choice" ]; then
		distribution=$(echo "$distro_choice" | cut -d'|' -f1)
		release=$(echo "$distro_choice" | cut -d'|' -f2)
		architecture=$(echo "$distro_choice" | cut -d'|' -f3)
	fi

	# Affichage des informations avant création
	zenity --question \
		--title="Confirmation" \
		--text="Création du conteneur avec les paramètres suivants:

        Nom: $ct_name
        Utilisateur: $username
        Distribution: $distribution
        Version: $release
        Architecture: $architecture

        Voulez-vous continuer ?" \
	--width=400 2>/dev/null || { msg "Annulation." 9; exit 0; }
	
	# Relancer le script en mode root pour la création
	msg "Lancement de la création du conteneur (sudo requis)..." 11
	sudo "$0" --name "$ct_name" --user "$username" --password "$password" \
		--distribution "$distribution" --release "$release" --architecture "$architecture" \
		--gui-create
}

cli_interface() {    
    # Demande du mot de passe si non fourni
    if [ -z "$password" ]; then
        msg "Mot de passe pour votre conteneur" 10
        read -r -s -p "Mot de passe pour l'utilisateur '$username': " password
        printf "\n"
        read -r -s -p "Confirmez le mot de passe: " password_confirm
        printf "\n"
        [ "$password" = "$password_confirm" ] || error "Les mots de passe ne correspondent pas" 4
    fi

    # Vérifier si le conteneur existe déjà
    if sudo lxc-ls | grep -qw "$ct_name"; then
        error "Le conteneur '$ct_name' existe déjà" 5
    fi

    msg "=== Création du conteneur '$ct_name' ===" 11
    sudo lxc-create -t download -n "$ct_name" -- \
        -d "$distribution" \
        -r "$release" \
        -a "$architecture"

    msg "=== Démarrage du conteneur ===" 11
    sudo lxc-start -n "$ct_name"

    msg "Attente du démarrage du conteneur..." 10
    sleep 3

    msg "=== Configuration du conteneur ===" 11

    # Script d'initialisation exécuté dans le conteneur
    sudo lxc-attach -n "$ct_name" -- bash -c "
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
    ct_ip=$(sudo lxc-ls -f | grep "^$ct_name " | awk '{print $5}')
    msg "Adresse IP: $ct_ip" 11
    msg "Connexion SSH: ssh $username@$ct_ip" 11
}

if [ "$interface" = "gui" ]; then
	gui_interface
else
	[ -x "$(which lxc-create)" ] || error "LXC n'est pas installé. Essayez: sudo apt install lxc" 3
	cli_interface
	create_container
fi

exit 0

