#!/usr/bin/env bash

# See https://raw.githubusercontent.com/wp-cli/scaffold-command/master/templates/install-wp-tests.sh

if [ $# -lt 3 ]; then
	echo "usage: $0 <db-name> <db-user> <db-pass> [db-host] [wp-version] [skip-database-creation]"
	exit 1
fi

DB_NAME=$1
DB_USER=$2
DB_PASS=$3
DB_HOST=${4-localhost}
WP_VERSION=${5-latest}
SKIP_DB_CREATE=${6-false}

TMPDIR=${TMPDIR-/tmp}
TMPDIR=$(echo $TMPDIR | sed -e "s/\/$//")
WP_TESTS_DIR=${WP_TESTS_DIR-$TMPDIR/wordpress-tests-lib}
WP_TESTS_FILE="$WP_TESTS_DIR"/includes/functions.php
WP_CORE_DIR=${WP_CORE_DIR-$TMPDIR/wordpress}
WP_CORE_FILE="$WP_CORE_DIR"/wp-settings.php

download() {
    if [ `which curl` ]; then
        curl -s "$1" > "$2";
    elif [ `which wget` ]; then
        wget -nv -O "$2" "$1"
    else
        echo "Error: Neither curl nor wget is installed."
        exit 1
    fi
}

check_for_updates() {
	local remote_url="https://raw.githubusercontent.com/wp-cli/scaffold-command/main/templates/install-wp-tests.sh"
	local tmp_script="$TMPDIR/install-wp-tests.sh.latest"

	download "$remote_url" "$tmp_script"

	if [ ! -f "$tmp_script" ]; then
		echo "Warning: Could not download the latest version of the script for update check."
		return
	fi

	local local_hash=""
	local remote_hash=""

	if command -v shasum > /dev/null; then
		local_hash=$(shasum -a 256 "$0" | awk '{print $1}')
		remote_hash=$(shasum -a 256 "$tmp_script" | awk '{print $1}')
	elif command -v sha256sum > /dev/null; then
		local_hash=$(sha256sum "$0" | awk '{print $1}')
		remote_hash=$(sha256sum "$tmp_script" | awk '{print $1}')
	else
		echo "Warning: Could not find shasum or sha256sum to check for script updates."
		rm "$tmp_script"
		return
	fi

	rm "$tmp_script"

	if [ "$local_hash" != "$remote_hash" ]; then
		echo "Warning: A newer version of this script is available at $remote_url"
	fi
}
check_for_updates

if [[ $WP_VERSION =~ ^[0-9]+\.[0-9]+\-(beta|RC)[0-9]+$ ]]; then
	WP_BRANCH=${WP_VERSION%\-*}
	WP_TESTS_TAG="branches/$WP_BRANCH"

elif [[ $WP_VERSION =~ ^[0-9]+\.[0-9]+$ ]]; then
	WP_TESTS_TAG="branches/$WP_VERSION"
elif [[ $WP_VERSION =~ [0-9]+\.[0-9]+\.[0-9]+ ]]; then
	if [[ $WP_VERSION =~ [0-9]+\.[0-9]+\.[0] ]]; then
		# version x.x.0 means the first release of the major version, so strip off the .0 and download version x.x
		WP_TESTS_TAG="tags/${WP_VERSION%??}"
	else
		WP_TESTS_TAG="tags/$WP_VERSION"
	fi
elif [[ $WP_VERSION == 'nightly' || $WP_VERSION == 'trunk' ]]; then
	WP_TESTS_TAG="trunk"
else
	# http serves a single offer, whereas https serves multiple. we only want one
	download http://api.wordpress.org/core/version-check/1.7/ /tmp/wp-latest.json
	grep '[0-9]+\.[0-9]+(\.[0-9]+)?' /tmp/wp-latest.json
	LATEST_VERSION=$(grep -o '"version":"[^"]*' /tmp/wp-latest.json | sed 's/"version":"//')
	if [[ -z "$LATEST_VERSION" ]]; then
		echo "Latest WordPress version could not be found"
		exit 1
	fi
	WP_TESTS_TAG="tags/$LATEST_VERSION"
fi
set -ex

install_wp() {

	if [ -f $WP_CORE_FILE ]; then
		return;
	fi

	rm -rf $WP_CORE_DIR
	mkdir -p $WP_CORE_DIR

	if [[ $WP_VERSION == 'nightly' || $WP_VERSION == 'trunk' ]]; then
		download https://github.com/WordPress/wordpress-develop/archive/refs/heads/master.tar.gz $WP_CORE_DIR
	else
		if [ $WP_VERSION == 'latest' ]; then
			local ARCHIVE_NAME='latest'
		elif [[ $WP_VERSION =~ [0-9]+\.[0-9]+ ]]; then
			# https serves multiple offers, whereas http serves single.
			download https://api.wordpress.org/core/version-check/1.7/ $TMPDIR/wp-latest.json
			if [[ $WP_VERSION =~ [0-9]+\.[0-9]+\.[0] ]]; then
				# version x.x.0 means the first release of the major version, so strip off the .0 and download version x.x
				LATEST_VERSION=${WP_VERSION%??}
			else
				# otherwise, scan the releases and get the most up to date minor version of the major release
				local VERSION_ESCAPED=`echo $WP_VERSION | sed 's/\./\\\\./g'`
				LATEST_VERSION=$(grep -o '"version":"'$VERSION_ESCAPED'[^"]*' $TMPDIR/wp-latest.json | sed 's/"version":"//' | head -1)
			fi
			if [[ -z "$LATEST_VERSION" ]]; then
				local ARCHIVE_NAME="wordpress-$WP_VERSION"
			else
				local ARCHIVE_NAME="wordpress-$LATEST_VERSION"
			fi
		else
			local ARCHIVE_NAME="wordpress-$WP_VERSION"
		fi
		download https://wordpress.org/${ARCHIVE_NAME}.tar.gz  $TMPDIR/wordpress.tar.gz
		tar --strip-components=1 -zxmf $TMPDIR/wordpress.tar.gz -C $WP_CORE_DIR
	fi
}

install_test_suite() {
	# portable in-place argument for both GNU sed and Mac OSX sed
	if [[ $(uname -s) == 'Darwin' ]]; then
		local ioption='-i.bak'
	else
		local ioption='-i'
	fi

	# set up testing suite if it doesn't yet exist or only partially exists
	if [ ! -f $WP_TESTS_FILE ]; then
		# set up testing suite
		rm -rf $WP_TESTS_DIR
		mkdir -p $WP_TESTS_DIR

		if [[ $WP_TESTS_TAG == 'trunk' ]]; then
			ref=master
			archive_url="https://github.com/WordPress/wordpress-develop/archive/refs/heads/${ref}.tar.gz"
		elif [[ $WP_TESTS_TAG == branches/* ]]; then
			ref=${WP_TESTS_TAG#branches/}
			archive_url="https://github.com/WordPress/wordpress-develop/archive/refs/heads/${ref}.tar.gz"
		else
			ref=${WP_TESTS_TAG#tags/}
			archive_url="https://github.com/WordPress/wordpress-develop/archive/refs/tags/${ref}.tar.gz"
		fi

		download ${archive_url} $TMPDIR/wordpress-develop.tar.gz
		tar -zxmf $TMPDIR/wordpress-develop.tar.gz -C $TMPDIR
		mv $TMPDIR/wordpress-develop-${ref}/tests/phpunit/includes $WP_TESTS_DIR/
		mv $TMPDIR/wordpress-develop-${ref}/tests/phpunit/data $WP_TESTS_DIR/
		rm -rf $TMPDIR/wordpress-develop-${ref}
		rm $TMPDIR/wordpress-develop.tar.gz
	fi

	if [ ! -f wp-tests-config.php ]; then
		if [[ $WP_TESTS_TAG == 'trunk' ]]; then
			ref=master
		elif [[ $WP_TESTS_TAG == branches/* ]]; then
			ref=${WP_TESTS_TAG#branches/}
		else
			ref=${WP_TESTS_TAG#tags/}
		fi
		download https://raw.githubusercontent.com/WordPress/wordpress-develop/${ref}/wp-tests-config-sample.php "$WP_TESTS_DIR"/wp-tests-config.php
		# remove all forward slashes in the end
		WP_CORE_DIR=$(echo $WP_CORE_DIR | sed "s:/\+$::")
		sed $ioption "s:dirname( __FILE__ ) . '/src/':'$WP_CORE_DIR/':" "$WP_TESTS_DIR"/wp-tests-config.php
		sed $ioption "s/youremptytestdbnamehere/$DB_NAME/" "$WP_TESTS_DIR"/wp-tests-config.php
		sed $ioption "s/yourusernamehere/$DB_USER/" "$WP_TESTS_DIR"/wp-tests-config.php
		sed $ioption "s/yourpasswordhere/$DB_PASS/" "$WP_TESTS_DIR"/wp-tests-config.php
		sed $ioption "s|localhost|${DB_HOST}|" "$WP_TESTS_DIR"/wp-tests-config.php
	fi

}

recreate_db() {
	shopt -s nocasematch
	if [[ $1 =~ ^(y|yes)$ ]]
	then
		if [ `which mariadb-admin` ]; then
			mariadb-admin drop $DB_NAME -f --user="$DB_USER" --password="$DB_PASS"$EXTRA
		else
			mysqladmin drop $DB_NAME -f --user="$DB_USER" --password="$DB_PASS"$EXTRA
		fi
		create_db
		echo "Recreated the database ($DB_NAME)."
	else
		echo "Leaving the existing database ($DB_NAME) in place."
	fi
	shopt -u nocasematch
}

create_db() {
	if [ `which mariadb-admin` ]; then
		mariadb-admin create $DB_NAME --user="$DB_USER" --password="$DB_PASS"$EXTRA
	else
		mysqladmin create $DB_NAME --user="$DB_USER" --password="$DB_PASS"$EXTRA
	fi
}

install_db() {

	if [ ${SKIP_DB_CREATE} = "true" ]; then
		return 0
	fi

	# parse DB_HOST for port or socket references
	local PARTS=(${DB_HOST//\:/ })
	local DB_HOSTNAME=${PARTS[0]};
	local DB_SOCK_OR_PORT=${PARTS[1]};
	local EXTRA=""

	if ! [ -z $DB_HOSTNAME ] ; then
		if [ $(echo $DB_SOCK_OR_PORT | grep -e '^[0-9]\{1,\}$') ]; then
			EXTRA=" --host=$DB_HOSTNAME --port=$DB_SOCK_OR_PORT --protocol=tcp"
		elif ! [ -z $DB_SOCK_OR_PORT ] ; then
			EXTRA=" --socket=$DB_SOCK_OR_PORT"
		elif ! [ -z $DB_HOSTNAME ] ; then
			EXTRA=" --host=$DB_HOSTNAME --protocol=tcp"
		fi
	fi

	# create database
	if [ `which mariadb` ]; then
		local DB_CLIENT='mariadb'
	else
		local DB_CLIENT='mysql'
	fi
	if [ $($DB_CLIENT --user="$DB_USER" --password="$DB_PASS"$EXTRA --execute='show databases;' | grep ^$DB_NAME$) ]
	then
		echo "Reinstalling will delete the existing test database ($DB_NAME)"
		read -p 'Are you sure you want to proceed? [y/N]: ' DELETE_EXISTING_DB
		recreate_db $DELETE_EXISTING_DB
	else
		create_db
	fi
}

install_wp
install_test_suite
install_db
