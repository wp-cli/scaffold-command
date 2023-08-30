<?php

if ( ! class_exists( 'WP_CLI' ) ) {
	return;
}

$wpcli_scaffold_autoloader = __DIR__ . '/vendor/autoload.php';
if ( file_exists( $wpcli_scaffold_autoloader ) ) {
	require_once $wpcli_scaffold_autoloader;
}

WP_CLI::add_command( 'scaffold', 'Scaffold_Command' );
