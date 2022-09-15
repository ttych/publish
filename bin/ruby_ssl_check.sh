#!/bin/sh

# From:
# https://bundler.io/guides/rubygems_tls_ssl_troubleshooting_guide.html#automated-ssl-check

curl -Lks 'https://git.io/rg-ssl' | ruby
