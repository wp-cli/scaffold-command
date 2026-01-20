Feature: Lint scaffolded code

  Background:
    Given a WP install
    And I run `wp plugin path`
    And save STDOUT as {PLUGIN_DIR}

    # Create a helper plugin to install phpcs once for all scenarios
    When I run `wp scaffold plugin phpcs-helper --skip-tests`
    Then the return code should be 0

    # Install coding standards
    When I run `composer config --working-dir={PLUGIN_DIR}/phpcs-helper allow-plugins.dealerdirect/phpcodesniffer-composer-installer true`
    Then the return code should be 0

    When I run `composer require --dev --working-dir={PLUGIN_DIR}/phpcs-helper dealerdirect/phpcodesniffer-composer-installer wp-coding-standards/wpcs --no-interaction --quiet`
    Then the return code should be 0

  Scenario: Scaffold plugin and lint it
    When I run `wp scaffold plugin test-plugin`
    Then STDOUT should not be empty
    And the {PLUGIN_DIR}/test-plugin/test-plugin.php file should exist
    And the {PLUGIN_DIR}/test-plugin/.phpcs.xml.dist file should exist

    When I run `{PLUGIN_DIR}/phpcs-helper/vendor/bin/phpcs --standard=WordPress {PLUGIN_DIR}/test-plugin/test-plugin.php`
    Then the return code should be 0

  Scenario: Scaffold post-type and lint it
    When I run `wp theme install twentytwentyone --force --activate`
    And I run `wp eval 'echo STYLESHEETPATH;'`
    And save STDOUT as {STYLESHEETPATH}

    And I run `wp scaffold post-type movie --theme`
    Then STDOUT should not be empty
    And the {STYLESHEETPATH}/post-types/movie.php file should exist

    When I run `{PLUGIN_DIR}/phpcs-helper/vendor/bin/phpcs --standard=WordPress {STYLESHEETPATH}/post-types/movie.php`
    Then the return code should be 0

  Scenario: Scaffold taxonomy and lint it
    When I run `wp theme install twentytwentyone --force --activate`
    And I run `wp eval 'echo STYLESHEETPATH;'`
    And save STDOUT as {STYLESHEETPATH}

    And I run `wp scaffold taxonomy genre --theme`
    Then STDOUT should not be empty
    And the {STYLESHEETPATH}/taxonomies/genre.php file should exist

    When I run `{PLUGIN_DIR}/phpcs-helper/vendor/bin/phpcs --standard=WordPress {STYLESHEETPATH}/taxonomies/genre.php`
    Then the return code should be 0

  Scenario: Scaffold plugin tests and lint them
    When I run `wp scaffold plugin test-plugin`
    Then STDOUT should not be empty
    And the {PLUGIN_DIR}/test-plugin/tests directory should exist
    And the {PLUGIN_DIR}/test-plugin/tests/bootstrap.php file should exist
    And the {PLUGIN_DIR}/test-plugin/tests/test-sample.php file should exist

    # Run phpcs on the test files
    When I run `{PLUGIN_DIR}/phpcs-helper/vendor/bin/phpcs --standard=WordPress {PLUGIN_DIR}/test-plugin/tests/bootstrap.php {PLUGIN_DIR}/test-plugin/tests/test-sample.php`
    Then the return code should be 0

  Scenario: Scaffold child theme and lint it
    When I run `wp theme install twentytwentyone --force --activate`
    And I run `wp theme path`
    And save STDOUT as {THEME_DIR}

    And I run `wp scaffold child-theme test-child --parent_theme=twentytwentyone`
    Then STDOUT should not be empty
    And the {THEME_DIR}/test-child/functions.php file should exist

    When I run `{PLUGIN_DIR}/phpcs-helper/vendor/bin/phpcs --standard=WordPress {THEME_DIR}/test-child/functions.php`
    Then the return code should be 0

  Scenario: Scaffold block and lint it
    When I run `wp scaffold plugin movies`
    And I run `wp plugin path movies --dir`
    And save STDOUT as {MOVIES_DIR}

    And I run `wp scaffold block the-green-mile --plugin=movies`
    Then STDOUT should not be empty
    And the {MOVIES_DIR}/blocks/the-green-mile.php file should exist

    When I run `{PLUGIN_DIR}/phpcs-helper/vendor/bin/phpcs --standard=WordPress {MOVIES_DIR}/blocks/the-green-mile.php`
    Then the return code should be 0
