<?php

/**
 * Fallback filesystem class for when WordPress is not available.
 *
 * Provides a compatible interface with WP_Filesystem using native PHP functions.
 */
class Scaffold_Filesystem_Fallback {

	/**
	 * Creates a directory.
	 *
	 * @param string $path Directory path.
	 * @return bool True on success, false on failure.
	 */
	public function mkdir( $path ) {
		if ( file_exists( $path ) ) {
			return true;
		}
		// phpcs:ignore WordPress.WP.AlternativeFunctions.file_system_operations_mkdir
		return mkdir( $path, 0755, true );
	}

	/**
	 * Checks if a file or directory exists.
	 *
	 * @param string $path File or directory path.
	 * @return bool True if exists, false otherwise.
	 */
	public function exists( $path ) {
		return file_exists( $path );
	}

	/**
	 * Writes content to a file.
	 *
	 * @param string $file    File path.
	 * @param string $contents File contents.
	 * @return bool True on success, false on failure.
	 */
	public function put_contents( $file, $contents ) {
		// phpcs:ignore WordPress.WP.AlternativeFunctions.file_system_operations_file_put_contents
		$result = file_put_contents( $file, $contents );
		return false !== $result;
	}

	/**
	 * Copies a file.
	 *
	 * @param string $source      Source file path.
	 * @param string $destination Destination file path.
	 * @param bool   $overwrite   Whether to overwrite existing file.
	 * @return bool True on success, false on failure.
	 */
	public function copy( $source, $destination, $overwrite = false ) {
		if ( ! $overwrite && file_exists( $destination ) ) {
			return false;
		}
		// Ensure the destination directory exists.
		$dir = dirname( $destination );
		if ( ! file_exists( $dir ) ) {
			$this->mkdir( $dir );
		}
		// phpcs:ignore WordPress.WP.AlternativeFunctions.file_system_operations_copy
		return copy( $source, $destination );
	}

	/**
	 * Changes file permissions.
	 *
	 * @param string $file File path.
	 * @param int    $mode Permission mode (octal).
	 * @return bool True on success, false on failure.
	 */
	public function chmod( $file, $mode ) {
		// phpcs:ignore WordPress.WP.AlternativeFunctions.file_system_operations_chmod
		return chmod( $file, $mode );
	}
}
