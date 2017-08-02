#!/bin/bash

let SKIP_DB_CREATE=0
let SKIP_WP_CONFIG=0
let FORCE_WP_CONFIG=0
let have_specified_password=0

_usage() {
    cat <<EOF
$(basename $0):
  Setup a test-ready WordPress installation, configuring the necessary wp-tests-config.php on the way

Usage:
  $(basename $0) -d <db-name> -u <db-user> -p <db-pass> [-H <db-host>] [-v <wp-version>] [--skip-db-create] [--skip-wp-config] [--force-wp-config] [-D <domain>] [-t theme] [-I <php-file>]
EOF
}

while :; do
   case "$1" in
       -h|-\?|--help)
	   _usage && exit
	   ;;
       -d|--db)
	   [[ -z "$2" ]] && echo >&2 "--db requires a argument" && exit 1
	   DB_NAME="$2" && shift
	   ;;
       -u|--user)
	   [[ -z "$2" ]] && echo >&2 "--user requires a argument" && exit 1
	   DB_USER="$2" && shift
	   ;;
       -p|--pass)
	   if (( $# < 2 )) || [[ $2 =~ -- ]]; then echo >&2 "--pass requires a argument even if empty" && exit 1; fi
	   have_specified_password=1
	   DB_PASSWORD="$2" && shift
	   ;;
       -H|--db-hostname)
	   [[ -z "$2" ]] && echo >&2 "--db-hostname requires a argument" && exit 1
	   DB_HOST="$2" && shift
	   ;;
       -P|--table-prefix)
	   if (( $# < 2 )) || [[ $2 =~ -- ]]; then echo >&2 "--table-prefix requires a argument even if empty" && exit 1; fi
	   TABLE_PREFIX="$2" && shift
	   ;;
       -v|--version)
	   [[ -z "$2" ]] && echo >&2 "--version requires a argument" && exit 1
	   WP_VERSION="$2" && shift
	   ;;
       --skip-db-create)
	   SKIP_DB_CREATE=1
	   ;;
       --skip-wp-config)
	   SKIP_WP_CONFIG=1
	   ;;
       --force-wp-config)
	   FORCE_WP_CONFIG=1
	   ;;
       -D|--domain)
	   [[ -z "$2" ]] && echo >&2 "--domain requires a argument" && exit 1
	   WP_TESTS_DOMAIN="$2" && shift
	   ;;
       -t|--theme)
	   [[ -z "$2" ]] && echo >&2 "--theme requires a argument" && exit 1
	   WP_DEFAULT_THEME="$2" && shift
	   ;;
       -I|--include)
	   [[ -z "$2" ]] && echo >&2 "--include requires a argument" && exit 1
	   [[ ! -f "$2" ]] && echo >&2 "--include argument must be an existing PHP file" && exit 1
	   INCLUDE_FILE="$2" && shift
	   ;;
       *)
	   break
	   ;;
   esac
   shift
done


[[ ! $DB_NAME ]] && echo >&2 "missing a -d|--db option" && _usage && exit 1
[[ ! $DB_USER ]] && echo >&2 "missing a -u|--user" && _usage && exit 1
(( ! $have_specified_password )) && echo >&2 "missing a -p|--pass option" && _usage && exit 1

if ! type -P curl &>/dev/null && ! type -P wget &>/dev/null; then
    echo >&2 "$(basename $0) need curl|wget to fetch WP archive" && exit 1
fi

if ! type -P svn &>/dev/null; then
    echo >&2 "$(basename $0) need svn to fetch WP component" && exit 1
fi


DB_HOST=${DB_HOST:-localhost}
WP_VERSION=${WP_VERSION:-latest}
TABLE_PREFIX=${TABLE_PREFIX:-wptests_}
WP_TESTS_DOMAIN=${WP_TESTS_DOMAIN:-example.org}
WP_DEFAULT_THEME=${WP_DEFAULT_THEME:-default}

# from environment
WP_TESTS_DIR=${WP_TESTS_DIR-/tmp/wordpress-tests-lib}
WP_CORE_DIR=${WP_CORE_DIR-/tmp/wordpress/}

download() {
    # for raw-github, curl *must* follow 301 otherwise it will fetch... nothing
    if [ `which curl` ]; then
        curl -Ls "$1" > "$2";
    elif [ `which wget` ]; then
        wget -nv -O "$2" "$1"
    fi
}

if [[ $WP_VERSION =~ [0-9]+\.[0-9]+(\.[0-9]+)? ]]; then
	WP_TESTS_TAG="tags/$WP_VERSION"
elif [[ $WP_VERSION == 'nightly' || $WP_VERSION == 'trunk' ]]; then
	WP_TESTS_TAG="trunk"
else
	# http serves a single offer, whereas https serves multiple. we only want one
        # or use HTTPS and script using python or use jq;
        # jq -r '.offers[] | select(.response=="upgrade").version'
	download http://api.wordpress.org/core/version-check/1.7/ /tmp/wp-latest.json
	grep '[0-9]+\.[0-9]+(\.[0-9]+)?' /tmp/wp-latest.json
	if ! WP_TESTS_TAG=tags/$(grep -Po '"version":"\K([^"]+)' /tmp/wp-latest.json); then
	    echo >&2 "Latest WordPress version could not be found" && exit 1
	fi
fi

install_wp() {
	mkdir -p $WP_CORE_DIR

	if [[ $WP_VERSION == 'nightly' || $WP_VERSION == 'trunk' ]]; then
		mkdir -p /tmp/wordpress-nightly
		download https://wordpress.org/nightly-builds/wordpress-latest.zip  /tmp/wordpress-nightly/wordpress-nightly.zip
		unzip -q /tmp/wordpress-nightly/wordpress-nightly.zip -d /tmp/wordpress-nightly/
		mv /tmp/wordpress-nightly/wordpress/* $WP_CORE_DIR
	else
		if [ $WP_VERSION == 'latest' ]; then
			local ARCHIVE_NAME='latest'
		else
			local ARCHIVE_NAME="wordpress-$WP_VERSION"
		fi
		download https://wordpress.org/${ARCHIVE_NAME}.tar.gz  /tmp/wordpress.tar.gz
		tar --strip-components=1 -zxmf /tmp/wordpress.tar.gz -C $WP_CORE_DIR
	fi

	download https://raw.github.com/markoheijnen/wp-mysqli/master/db.php $WP_CORE_DIR/wp-content/db.php
}

install_test_suite() {
        # set up testing suite
        mkdir -p $WP_TESTS_DIR
	svn co --quiet https://develop.svn.wordpress.org/${WP_TESTS_TAG}/tests/phpunit/includes/ $WP_TESTS_DIR/includes
	svn co --quiet https://develop.svn.wordpress.org/${WP_TESTS_TAG}/tests/phpunit/data/ $WP_TESTS_DIR/data
}

config_wp() {
	# portable in-place argument for both GNU sed and Mac OSX sed
	if [[ $(uname -s) == 'Darwin' ]]; then
		local ioption='-i .bak'
	else
		local ioption='-i'
	fi

	# ToDo: $WP_TESTS_DIR
	if [[ ! -f wp-tests-config.php ]] || (( $FORCE_WP_CONFIG )); then
	        # ToDo: manage 500/404
		download https://develop.svn.wordpress.org/${WP_TESTS_TAG}/wp-tests-config-sample.php "$WP_TESTS_DIR"/wp-tests-config.php
		# remove all forward slashes in the end
		WP_CORE_DIR=$(echo $WP_CORE_DIR | sed "s:/\+$::")
		sed $ioption \
		    -e "s:dirname( __FILE__ ) . '/src/':'$WP_CORE_DIR/':" \
		    -e "/DB_NAME/s/youremptytestdbnamehere/$DB_NAME/" \
		    -e "/DB_USER/s/yourusernamehere/$DB_USER/" \
		    -e "/DB_PASSWORD/s/yourpasswordhere/$DB_PASSWORD/" \
		    -e "/DB_HOST/s|localhost|${DB_HOST}|" \
		    -e "/WP_TESTS_DOMAIN/s!example.org!$WP_TESTS_DOMAIN!" \
		    -e "/WP_DEFAULT_THEME/s!default!$WP_DEFAULT_THEME!" \
		    -e "/table_prefix/s!wptests_!$TABLE_PREFIX!" "$WP_TESTS_DIR"/wp-tests-config.php

		[[ -n "$INCLUDE_FILE" ]] && cat "$INCLUDE_FILE" >> "$WP_TESTS_DIR"/wp-tests-config.php
	fi
}

install_db() {
	# parse DB_HOST for port or socket references
	local PARTS=(${DB_HOST//\:/ })
	local DB_HOSTNAME=${PARTS[0]};
	local DB_SOCK_OR_PORT=${PARTS[1]};
	local EXTRA=""

	if [[ -n "$DB_HOSTNAME" ]] ; then
		if [[ $DB_SOCK_OR_PORT =~ ^[0-9]{1,}$ ]]; then
			EXTRA=" --host=$DB_HOSTNAME --port=$DB_SOCK_OR_PORT --protocol=tcp"
		elif ! [ -z $DB_SOCK_OR_PORT ] ; then
			EXTRA=" --socket=$DB_SOCK_OR_PORT"
		elif ! [ -z $DB_HOSTNAME ] ; then
			EXTRA=" --host=$DB_HOSTNAME --protocol=tcp"
		fi
	fi

	# create database
	mysqladmin create $DB_NAME --user="$DB_USER" --password="$DB_PASSWORD"$EXTRA
}

set -x

[[ -d $WP_CORE_DIR ]] || install_wp

# set up testing suite if it doesn't yet exist
[[ ! -d $WP_TESTS_DIR ]] && theninstall_test_suite

(( SKIP_WP_CONFIG )) || config_wp
(( SKIP_DB_CREATE )) || install_db
