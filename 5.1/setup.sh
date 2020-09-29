#!/bin/bash

if [[ ${ENABLE_SSL} == "true" ]]; then
  sed -i '/SSLCertificateFile/d' /etc/apache2/sites-available/default-ssl.conf
  sed -i '/SSLCertificateKeyFile/d' /etc/apache2/sites-available/default-ssl.conf
  sed -i '/SSLCertificateChainFile/d' /etc/apache2/sites-available/default-ssl.conf

  sed -i 's/SSLEngine.*/SSLEngine on\nSSLCertificateFile \/etc\/apache2\/ssl\/cert.pem\nSSLCertificateKeyFile \/etc\/apache2\/ssl\/private_key.pem\nSSLCertificateChainFile \/etc\/apache2\/ssl\/cert-chain.pem/' /etc/apache2/sites-available/default-ssl.conf

  ln -s /etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-enabled/

  /usr/sbin/a2enmod ssl
else
  /usr/sbin/a2dismod ssl
  rm /etc/apache2/sites-enabled/default-ssl.conf
fi

/usr/sbin/a2enmod rewrite
/usr/sbin/a2enmod authnz_ldap
/usr/sbin/a2enconf remoteip
/usr/sbin/a2enmod remoteip

perl -i -pe 's/^(\s*LogFormat\s+.*)%h(.*)/\1%a\2/g' /etc/apache2/apache2.conf

# Limits: Default values
export UPLOAD_MAX_FILESIZE=${UPLOAD_MAX_FILESIZE:-300M}
export POST_MAX_SIZE=${POST_MAX_SIZE:-300M}
export MAX_EXECUTION_TIME=${MAX_EXECUTION_TIME:-360}
export MAX_FILE_UPLOADS=${MAX_FILE_UPLOADS:-20}
export MAX_INPUT_VARS=${MAX_INPUT_VARS:-1000}
export MEMORY_LIMIT=${MEMORY_LIMIT:-512M}

export DISABLE_WP_CRON=${DISABLE_WP_CRON:-false}
export AUTOMATIC_UPDATER_DISABLED=${AUTOMATIC_UPDATER_DISABLED:-true}

# Limits
perl -i -pe 's/^(\s*;\s*)*upload_max_filesize.*/upload_max_filesize = $ENV{'UPLOAD_MAX_FILESIZE'}/g' /etc/php/7.2/apache2/php.ini
perl -i -pe 's/^(\s*;\s*)*post_max_size.*/post_max_size = $ENV{'POST_MAX_SIZE'}/g' /etc/php/7.2/apache2/php.ini
perl -i -pe 's/^(\s*;\s*)*max_execution_time.*/max_execution_time = $ENV{'MAX_EXECUTION_TIME'}/g' /etc/php/7.2/apache2/php.ini
perl -i -pe 's/^(\s*;\s*)*max_file_uploads.*/max_file_uploads = $ENV{'MAX_FILE_UPLOADS'}/g' /etc/php/7.2/apache2/php.ini
perl -i -pe 's/^(\s*;\s*)*max_input_vars.*/max_input_vars = $ENV{'MAX_INPUT_VARS'}/g' /etc/php/7.2/apache2/php.ini
perl -i -pe 's/^(\s*;\s*)*memory_limit.*/memory_limit = $ENV{'MEMORY_LIMIT'}/g' /etc/php/7.2/apache2/php.ini

perl -i -pe 's/<\/VirtualHost>/<Directory \/var\/www\/html>\nAllowOverride ALL\n<\/Directory>\n<\/VirtualHost>/' /etc/apache2/sites-available/000-default.conf

mkdir -p "/var/www/html/${RELATIVE_PATH}"
rsync -au /opt/wordpress/ "/var/www/html/${RELATIVE_PATH}"
rsync -au /opt/wp-plugins/ "/var/www/html/${RELATIVE_PATH}/wp-content/plugins"

find /var/www/html/ ! -user www-data -exec chown www-data: {} +

if [ -e "/usr/local/bin/wp" ]; then

  # wp-config.php anlegen
  if [ -z "${DBNAME+x}" ] || [ -z "${DBUSER+x}" ] || [ -z "${DBPASS+x}" ] || [ -z "${DBHOST+x}" ] || [ -z "${DBPREFIX+x}" ]; then
    echo "WARNING: skipping 'wp config create': One or more environment variables not defined: DBNAME, DBUSER, DBPASS, DBHOST, DBPREFIX"
  else
    su -s /bin/bash -c "/usr/local/bin/wp --path=/var/www/html/${RELATIVE_PATH} config create --dbname='${DBNAME}' --dbuser='${DBUSER}' --dbpass='${DBPASS}' --dbhost='${DBHOST}' --dbprefix='${DBPREFIX}' --skip-check --force --extra-php <<PHP

define('AUTOMATIC_UPDATER_DISABLED', ${AUTOMATIC_UPDATER_DISABLED});
define('DISABLE_WP_CRON', ${DISABLE_WP_CRON});
PHP
" www-data
  fi

  # WP initialisieren
  if [ -n "${INITIAL_TITLE}" ] && [ -n "${INITIAL_URL}" ] && [ -n "${INITIAL_ADMIN_USER}" ] && [ -n "${INITIAL_ADMIN_PASSWORD}" ] && [ -n "${INITIAL_ADMIN_EMAIL}" ]; then
    su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' core install --title='${INITIAL_TITLE}' --url='${INITIAL_URL}' --admin_user='${INITIAL_ADMIN_USER}' --admin_password='${INITIAL_ADMIN_PASSWORD}' --admin_email='${INITIAL_ADMIN_EMAIL}' --skip-email" www-data
  else
    echo "WARNING: skipping 'wp core install': One or more environment variables not defined: INITIAL_TITLE, INITIAL_URL, INITIAL_ADMIN_USER, INITIAL_ADMIN_PASSWORD, INITIAL_ADMIN_EMAIL"
  fi

  # Mitgelieferte Plugins sofort aktualisieren
  #su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin update --all" www-data

  # Updates the active translation of core, plugins, and themes.
  #su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' core language update" www-data
  #su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' theme update --all" www-data

  # WordPress Plugins
  su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install easy-wp-smtp" www-data
  su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install h5p" www-data
  su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install wpdirauth" www-data
  su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install easy-swipebox" www-data
  su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install shortcodes-ultimate" www-data
  su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install buddypress" www-data
  su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install akismet" www-data
  # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin install stops-core-theme-and-plugin-updates" www-data

  su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin activate wpdirauth" www-data
  su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin activate easy-wp-smtp" www-data
  su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin activate akismet" www-data
  # su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin activate stops-core-theme-and-plugin-updates" www-data

  su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin delete hello" www-data
  #su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin delete akismet" www-data

  if [ -d "/var/www/html/${RELATIVE_PATH}/wp-content/plugins/tuhh-filter/.git" ]; then git -C "/var/www/html/${RELATIVE_PATH}/wp-content/plugins/tuhh-filter/" pull; else git clone https://collaborating.tuhh.de/open-source/wordpress-plugins/tuhh-filter.git "/var/www/html/${RELATIVE_PATH}/wp-content/plugins/tuhh-filter/"; fi
  su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' plugin activate tuhh-filter" www-data
fi

echo "!!!! quick'n'dirty hack !!!!"
echo "Logout für LDAP auf 24 Stunden"
perl -i -pe 's/\$intExpireTime *= *.*/\$intExpireTime = 60 * 60 * 24;/g' "/var/www/html/${RELATIVE_PATH}/wp-content/plugins/wpdirauth/wpDirAuth.php"

if [ -n "${WP_THROTTLE_COMMENT_FLOOT_TIMEOUT}" ]; then
  echo "!!!! quick'n'dirty hack !!!!"
  echo "WP_THROTTLE_COMMENT_FLOOT_TIMEOUT (Default 15) ersetzen"
  perl -i -pe 's/(if\s*\(\s*\(\$time_newcomment\s*-\s*\$time_lastcomment\)\s*<\s*)15(\s*\))/${1}$ENV{'WP_THROTTLE_COMMENT_FLOOT_TIMEOUT'}${2}/g' "/var/www/html/${RELATIVE_PATH}/wp-includes/comment.php"
fi

echo 'Correction of insecure internal links …'
if [[ $ENABLE_SSL == true ]]; then
  site_url=$(su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' option get siteurl" www-data)
  fqdn=$(perl -lne 'print $1 if /http(?:s|):\/\/(.*)/' <<<"${site_url}")
  if [ -n "${fqdn}" ]; then
    su -s /bin/bash -c "/usr/local/bin/wp --path='/var/www/html/${RELATIVE_PATH}' search-replace --report-changed-only http://${fqdn} https://${fqdn}" www-data
  fi
fi

find /var/www/html -type f -print0 | xargs -0 chmod 660
find /var/www/html -type d -print0 | xargs -0 chmod 770

chmod 440 "/var/www/html/${RELATIVE_PATH}/.htaccess"

exec /usr/bin/supervisord -nc /etc/supervisord.conf
