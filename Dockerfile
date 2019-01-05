# from https://www.drupal.org/docs/8/system-requirements/drupal-8-php-requirements
FROM php:7.2-apache

# install the PHP extensions we need
RUN set -ex; \
	\
	if command -v a2enmod; then \
		a2enmod rewrite; \
	fi; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libjpeg-dev \
		libpng-dev \
		libpq-dev \
    libldap2-dev \
    git \
    unzip \
    mysql-client \
	; \
	\
	docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr; \
  docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/; \
	docker-php-ext-install -j "$(nproc)" \
		gd \
		pdo_mysql \
		zip \
    bcmath \
		ldap \
	; \
	\
# # reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
# 	apt-mark auto '.*' > /dev/null; \
# 	apt-mark manual $savedAptMark; \
# 	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
# 		| awk '/=>/ { print $3 }' \
# 		| sort -u \
# 		| xargs -r dpkg-query -S \
# 		| cut -d: -f1 \
# 		| sort -u \
# 		| xargs -rt apt-mark manual; \
# 	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*

RUN echo "memory_limit=-1" > "$PHP_INI_DIR/conf.d/memory-limit.ini" \
 && echo "date.timezone=${PHP_TIMEZONE:-UTC}" > "$PHP_INI_DIR/conf.d/date_timezone.ini"

ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_HOME /tmp
ENV COMPOSER_VERSION 1.8.0

RUN curl --silent --fail --location --retry 3 --output /tmp/installer.php --url https://raw.githubusercontent.com/composer/getcomposer.org/b107d959a5924af895807021fcef4ffec5a76aa9/web/installer \
 && php -r " \
    \$signature = '544e09ee996cdf60ece3804abc52599c22b1f40f4323403c44d44fdfdd586475ca9813a858088ffbc1f233e9b180f061'; \
    \$hash = hash('SHA384', file_get_contents('/tmp/installer.php')); \
    if (!hash_equals(\$signature, \$hash)) { \
        unlink('/tmp/installer.php'); \
        echo 'Integrity check failed, installer is either corrupt or worse.' . PHP_EOL; \
        exit(1); \
    }" \
 && php /tmp/installer.php --no-ansi --install-dir=/usr/bin --filename=composer --version=${COMPOSER_VERSION} \
 && composer --ansi --version --no-interaction \
 && rm -rf /tmp/* /tmp/.htaccess

ENV DRUPAL_CONSOLE_ALIAS dp
RUN echo "alias $DRUPAL_CONSOLE_ALIAS=\"cd /var/www/html/web; ../vendor/bin/drupal\"" >> ~/.bashrc

ENV DRUSH_ALIAS dr
RUN echo "alias $DRUSH_ALIAS=\"cd /var/www/html/web; ../vendor/bin/drush\"" >> ~/.bashrc

ENV APACHE_DOCUMENT_ROOT /var/www/html

RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf
