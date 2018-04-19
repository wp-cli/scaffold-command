#!/bin/bash

set -ex

# Run the unit tests, if they exist
if [ -f "phpunit.xml" ] || [ -f "phpunit.xml.dist" ]
then
	phpunit
fi

if [ $WP_VERSION = "latest" ]; then
	export WP_VERSION=$(curl -s https://api.wordpress.org/core/version-check/1.7/ | jq -r ".offers[0].current")
fi

# Run the functional tests
BEHAT_TAGS=$(php utils/behat-tags.php)
behat --format progress $BEHAT_TAGS --strict
