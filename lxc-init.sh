#! /usr/bin/env bash

c0=$(tput sgr0)
myself=$(basename "$0")

# Configuration par défaut
distribution="debian"
release="trixie"
architecture="amd64"

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
opts=$(getopt -o n:u:d:r:a:h --long name:,user:,distribution:,release:,architecture:,help -n "$myself" -- "$@") \
	|| error "getopt failed with error code: $?" 1
eval set -- "$opts"

ct_name=""

while true; do
	case "$1" in
		-n|--name) ct_name="$2"; shift 2 ;;
		-u|--user) username="$2"; shift 2 ;;
		-d|--distribution) distribution="$2"; shift 2 ;;
		-r|--release) release="$2"; shift 2 ;;
		-a|--architecture) architecture="$2"; shift 2 ;;
		-h|--help) usage; exit 0 ;;
		--) shift; break ;;
		*) break ;;
	esac
done

# Gestion des permissions
sudo -k
sudo -v

# Creation Conteneur
sudo lxc-create -t download -n "$ct_name" -- -d "$distribution" -r "$release" -a "$architecture"

msg "=== Démarrage du conteneur ===" 11
sudo lxc-start -n "$ct_name"

msg "=== Configuration du conteneur  ===" 11
sudo lxc-attach -n "$ct_name" -- bash -c "
uname -a
"

msg "=== Arret et suppression ===" 11
sudo lxc-stop "$ct_name"
sudo lxc-destroy "$ct_name"

