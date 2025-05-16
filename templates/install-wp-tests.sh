#!/usr/bin/env bash

# Colors for better readability
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
RESET=$(tput sgr0)

# Usage message
if [ $# -lt 3 ]; then
    echo "${RED}Usage: $0 <db-name> <db-user> <db-pass> [db-host] [wp-version] [skip-database-creation]${RESET}"
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
WP_CORE_DIR=${WP_CORE_DIR-$TMPDIR/wordpress}

# Download function with progress output
download() {
    echo "${CYAN}Downloading: $1 -> $2${RESET}"
    if [ `which curl` ]; then
        curl -s "$1" > "$2";
    elif [ `which wget` ]; then
        wget -nv -O "$2" "$1"
    else
        echo "${RED}Error: Neither curl nor wget is installed.${RESET}"
        exit 1
    fi
}

# Check if svn is installed
check_svn_installed() {
    if ! command -v svn > /dev/null; then
        echo "${RED}Error: svn is not installed. Please install svn and try again.${RESET}"
        exit 1
    fi
}

# Install WordPress
install_wp() {
    if [ -d $WP_CORE_DIR ]; then
        echo "${YELLOW}WordPress is already installed. Skipping.${RESET}"
        return
    fi

    echo "${CYAN}Installing WordPress...${RESET}"
    mkdir -p $WP_CORE_DIR

    if [[ $WP_VERSION == 'nightly' || $WP_VERSION == 'trunk' ]]; then
        mkdir -p $TMPDIR/wordpress-trunk
        rm -rf $TMPDIR/wordpress-trunk/*
        check_svn_installed
        echo "${GREEN}Exporting from SVN: trunk${RESET}"
        svn export --quiet https://core.svn.wordpress.org/trunk $TMPDIR/wordpress-trunk/wordpress
        mv $TMPDIR/wordpress-trunk/wordpress/* $WP_CORE_DIR
    else
        if [ $WP_VERSION == 'latest' ]; then
            local ARCHIVE_NAME='latest'
        else
            local ARCHIVE_NAME="wordpress-$WP_VERSION"
        fi
        download "https://wordpress.org/${ARCHIVE_NAME}.tar.gz" "$TMPDIR/wordpress.tar.gz"
        tar --strip-components=1 -zxmf $TMPDIR/wordpress.tar.gz -C $WP_CORE_DIR
        echo "${GREEN}WordPress installed in $WP_CORE_DIR${RESET}"
    fi

    download https://raw.githubusercontent.com/markoheijnen/wp-mysqli/master/db.php $WP_CORE_DIR/wp-content/db.php
}

# Install Test Suite
install_test_suite() {
    echo "${CYAN}Setting up the test suite...${RESET}"
    if [[ $(uname -s) == 'Darwin' ]]; then
        local ioption='-i.bak'
    else
        local ioption='-i'
    fi

    if [ ! -d $WP_TESTS_DIR ]; then
        echo "${GREEN}Downloading test suite...${RESET}"
        mkdir -p $WP_TESTS_DIR
        rm -rf $WP_TESTS_DIR/{includes,data}
        check_svn_installed
        svn export --quiet --ignore-externals https://develop.svn.wordpress.org/${WP_TESTS_TAG}/tests/phpunit/includes/ $WP_TESTS_DIR/includes
        svn export --quiet --ignore-externals https://develop.svn.wordpress.org/${WP_TESTS_TAG}/tests/phpunit/data/ $WP_TESTS_DIR/data
    fi

    if [ ! -f wp-tests-config.php ]; then
        download https://develop.svn.wordpress.org/${WP_TESTS_TAG}/wp-tests-config-sample.php "$WP_TESTS_DIR"/wp-tests-config.php
        WP_CORE_DIR=$(echo $WP_CORE_DIR | sed "s:/\+$::")
        sed $ioption "s:dirname( __FILE__ ) . '/src/':'$WP_CORE_DIR/':" "$WP_TESTS_DIR"/wp-tests-config.php
        sed $ioption "s:__DIR__ . '/src/':'$WP_CORE_DIR/':" "$WP_TESTS_DIR"/wp-tests-config.php
        sed $ioption "s/youremptytestdbnamehere/$DB_NAME/" "$WP_TESTS_DIR"/wp-tests-config.php
        sed $ioption "s/yourusernamehere/$DB_USER/" "$WP_TESTS_DIR"/wp-tests-config.php
        sed $ioption "s/yourpasswordhere/$DB_PASS/" "$WP_TESTS_DIR"/wp-tests-config.php
        sed $ioption "s|localhost|${DB_HOST}|" "$WP_TESTS_DIR"/wp-tests-config.php
    fi
    echo "${GREEN}Test suite configured successfully.${RESET}"
}

# Recreate Database if needed
recreate_db() {
    shopt -s nocasematch
    if [[ $1 =~ ^(y|yes)$ ]]; then
        mysqladmin drop $DB_NAME -f --user="$DB_USER" --password="$DB_PASS"$EXTRA
        create_db
        echo "${GREEN}Recreated the database ($DB_NAME).${RESET}"
    else
        echo "${YELLOW}Leaving the existing database ($DB_NAME) in place.${RESET}"
    fi
    shopt -u nocasematch
}

# Create Database
create_db() {
    echo "${CYAN}Creating the database $DB_NAME...${RESET}"
    mysqladmin create $DB_NAME --user="$DB_USER" --password="$DB_PASS"$EXTRA
    echo "${GREEN}Database $DB_NAME created.${RESET}"
}

# Install Database
install_db() {
    if [ ${SKIP_DB_CREATE} = "true" ]; then
        echo "${YELLOW}Skipping database creation.${RESET}"
        return 0
    fi

    echo "${CYAN}Setting up the database...${RESET}"
    local PARTS=(${DB_HOST//\:/ })
    local DB_HOSTNAME=${PARTS[0]};
    local DB_SOCK_OR_PORT=${PARTS[1]};
    local EXTRA=""

    if ! [ -z $DB_HOSTNAME ]; then
        if [ $(echo $DB_SOCK_OR_PORT | grep -e '^[0-9]\{1,\}$') ]; then
            EXTRA=" --host=$DB_HOSTNAME --port=$DB_SOCK_OR_PORT --protocol=tcp"
        elif ! [ -z $DB_SOCK_OR_PORT ]; then
            EXTRA=" --socket=$DB_SOCK_OR_PORT"
        else
            EXTRA=" --host=$DB_HOSTNAME --protocol=tcp"
        fi
    fi

    if [ $(mysql --user="$DB_USER" --password="$DB_PASS"$EXTRA --execute='show databases;' | grep ^$DB_NAME$) ]; then
        echo "${YELLOW}Reinstalling will delete the existing test database ($DB_NAME)${RESET}"
        read -p 'Are you sure you want to proceed? [y/N]: ' DELETE_EXISTING_DB
        recreate_db $DELETE_EXISTING_DB
    else
        create_db
    fi
}

# Start the installation process
echo "${CYAN}Starting the installation process...${RESET}"
install_wp
install_test_suite
install_db
echo "${GREEN}Installation complete!${RESET}"
