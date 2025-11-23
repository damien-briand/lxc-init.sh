#! /usr/bin/env bash

# Configuration par défaut
distribution="debian"
release="trixie"
architecture="amd64"

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

# Creation du conteneur

lxc-create -t download -n "$ct_name" -- -d "$distribution" -r "$release" -a "$architecture"

