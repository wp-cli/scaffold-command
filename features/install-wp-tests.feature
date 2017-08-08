Feature: Scaffold install-wp-tests.sh tests

  Scenario: Help should be displayed
    When I try `/usr/bin/env bash templates/install-wp-tests.sh`
    Then STDOUT should contain:
      """
      usage:
      """
    And the return code should be 1

  Scenario: Install latest version of WordPress
    Given I run `echo "DROP DATABASE IF EXISTS wordpress_behat_test" | mysql -u root`
    And I try `rm -fr /tmp/behat-wordpress-tests-lib`
    And I try `rm -fr /tmp/behat-wordpress`

    When I run `WP_TESTS_DIR=/tmp/behat-wordpress-tests-lib WP_CORE_DIR=/tmp/behat-wordpress /usr/bin/env bash templates/install-wp-tests.sh wordpress_behat_test root '' localhost latest`
    Then the return code should be 0
    And the /tmp/behat-wordpress-tests-lib directory should contain:
      """
      data
      """
    And the /tmp/behat-wordpress-tests-lib directory should contain:
      """
      includes
      """
    And the /tmp/behat-wordpress-tests-lib directory should contain:
      """
      wp-tests-config.php
      """
    And the /tmp/behat-wordpress directory should contain:
      """
      index.php
      license.txt
      readme.html
      wp-activate.php
      wp-admin
      wp-blog-header.php
      wp-comments-post.php
      wp-config-sample.php
      wp-content
      wp-cron.php
      wp-includes
      wp-links-opml.php
      wp-load.php
      wp-login.php
      wp-mail.php
      wp-settings.php
      wp-signup.php
      wp-trackback.php
      xmlrpc.php
      """

    When I run `echo 'show databases' | mysql -u root`
    Then the return code should be 0
    And STDOUT should contain:
      """
      wordpress_behat_test
      """

  Scenario: Install WordPress 3.7
    Given I run `echo "DROP DATABASE IF EXISTS wordpress_behat_test" | mysql -u root`
    And I try `rm -fr /tmp/behat-wordpress-tests-lib`
    And I try `rm -fr /tmp/behat-wordpress`

    When I run `WP_TESTS_DIR=/tmp/behat-wordpress-tests-lib WP_CORE_DIR=/tmp/behat-wordpress /usr/bin/env bash templates/install-wp-tests.sh wordpress_behat_test root '' localhost 3.7`
    Then the return code should be 0
    And the /tmp/behat-wordpress-tests-lib directory should contain:
      """
      data
      """
    And the /tmp/behat-wordpress-tests-lib directory should contain:
      """
      includes
      """
    And the /tmp/behat-wordpress-tests-lib directory should contain:
      """
      wp-tests-config.php
      """
    And the /tmp/behat-wordpress directory should contain:
      """
      index.php
      license.txt
      readme.html
      wp-activate.php
      wp-admin
      wp-blog-header.php
      wp-comments-post.php
      wp-config-sample.php
      wp-content
      wp-cron.php
      wp-includes
      wp-links-opml.php
      wp-load.php
      wp-login.php
      wp-mail.php
      wp-settings.php
      wp-signup.php
      wp-trackback.php
      xmlrpc.php
      """
    And the /tmp/behat-wordpress/wp-includes/version.php file should contain:
      """
      3.7
      """

    When I run `echo 'show databases' | mysql -u root`
    Then the return code should be 0
    And STDOUT should contain:
      """
      wordpress_behat_test
      """

  Scenario: Install WordPress from trunk
    Given I run `echo "DROP DATABASE IF EXISTS wordpress_behat_test" | mysql -u root`
    And I try `rm -fr /tmp/behat-wordpress-tests-lib`
    And I try `rm -fr /tmp/behat-wordpress`

    When I run `WP_TESTS_DIR=/tmp/behat-wordpress-tests-lib WP_CORE_DIR=/tmp/behat-wordpress /usr/bin/env bash templates/install-wp-tests.sh wordpress_behat_test root '' localhost trunk`
    Then the return code should be 0
    And the /tmp/behat-wordpress-tests-lib directory should contain:
      """
      data
      """
    And the /tmp/behat-wordpress-tests-lib directory should contain:
      """
      includes
      """
    And the /tmp/behat-wordpress-tests-lib directory should contain:
      """
      wp-tests-config.php
      """
    And the /tmp/behat-wordpress directory should contain:
      """
      index.php
      license.txt
      readme.html
      wp-activate.php
      wp-admin
      wp-blog-header.php
      wp-comments-post.php
      wp-config-sample.php
      wp-content
      wp-cron.php
      wp-includes
      wp-links-opml.php
      wp-load.php
      wp-login.php
      wp-mail.php
      wp-settings.php
      wp-signup.php
      wp-trackback.php
      xmlrpc.php
      """
    And the /tmp/behat-wordpress/wp-includes/version.php file should contain:
      """
      -alpha-
      """

    When I run `echo 'show databases' | mysql -u root`
    Then the return code should be 0
    And STDOUT should contain:
      """
      wordpress_behat_test
      """
