Feature: Scaffold a custom taxonomy

  Scenario: Scaffold a taxonomy that uses Doctrine pluralization
    Given a WP install

    When I run `wp scaffold taxonomy fungus --raw`
    Then STDOUT should contain:
      """
      __( 'Popular fungi'
      """
