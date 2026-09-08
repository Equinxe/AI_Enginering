# IA Engineering — starter Dockerfile (PHP)
#
# A minimal, multi-stage starter for a newly-bootstrapped PHP project using
# Composer. Not a production-hardened image — adjust the extensions, the
# document root, and the server configuration before relying on it.
#
# It ships PHP-FPM behind nginx in one image, which is the shape most PHP
# applications expect and the shortest path to a working container. A larger
# deployment usually splits them into two, and should.

# ---- vendor stage: resolve dependencies with Composer ----
FROM composer:2 AS vendor
WORKDIR /app
# Manifest and lock first, so the install layer is cached independently of
# source changes. The lock file is copied deliberately: an install that
# resolves fresh versions on every build is not reproducible.
COPY composer.json composer.lock* ./
RUN composer install \
      --no-dev \
      --no-scripts \
      --no-autoloader \
      --prefer-dist \
      --no-interaction

# ---- runtime stage ----
FROM php:8.3-fpm-alpine AS runtime
WORKDIR /var/www/html

# TODO: add the extensions your application actually needs. The commented line
# below is the common set for a database-backed app; installing extensions you
# do not use enlarges the image and its attack surface for nothing.
# RUN docker-php-ext-install pdo pdo_mysql opcache

RUN apk add --no-cache nginx

COPY --from=vendor /app/vendor ./vendor
COPY . .

# Composer's autoloader is generated here rather than in the vendor stage,
# because it must see the application's own classes — which are only present
# after the COPY above. Generating it earlier produces an autoloader that
# resolves dependencies and not your code, and the failure appears at runtime.
COPY --from=vendor /usr/bin/composer /usr/bin/composer
RUN composer dump-autoload --optimize --no-dev --no-interaction \
 && rm /usr/bin/composer

# TODO: `public` is the document root for Laravel, Symfony and most modern
# frameworks. Change it if yours differs — pointing nginx at the project root
# instead exposes composer.json, .env and your source to the internet.
RUN printf '%s\n' \
      'server {' \
      '  listen 80;' \
      '  root /var/www/html/public;' \
      '  index index.php;' \
      '  location / { try_files $uri $uri/ /index.php?$query_string; }' \
      '  location ~ \.php$ {' \
      '    fastcgi_pass 127.0.0.1:9000;' \
      '    fastcgi_index index.php;' \
      '    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;' \
      '    include fastcgi_params;' \
      '  }' \
      '}' \
    > /etc/nginx/http.d/default.conf

EXPOSE 80
# Both processes in the foreground. If either dies the container keeps running
# with the other, which is the known cost of one image; a deployment that needs
# to notice should split them or add a supervisor.
CMD ["sh", "-c", "php-fpm -D && nginx -g 'daemon off;'"]
