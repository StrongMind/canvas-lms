#!/bin/bash

rm -Rf canvas-lms
git clone https://github.com/strongmind/canvas-lms.git
cd canvas-lms
git checkout master
cp docker-compose/config/* ./config/
echo "COMPOSE_FILE=docker-compose.yml:docker-compose.override.yml:docker-compose.local.yml:docker-compose/selenium.override.yml" > .env
chown -R 9999:9999 ../canvas-lms
docker-compose down
docker rm -f $(docker ps -a -q)
docker rmi -f $(docker images -q)

cat  > docker-compose.local.yml << EOF
version: '2'
services:
  web:
    environment:
      CANVAS_LMS_ADMIN_EMAIL: canvas@example.edu
      CANVAS_LMS_ADMIN_PASSWORD: canvas-docker
      CANVAS_LMS_ACCOUNT_NAME: SMDockerized
      CANVAS_LMS_STATS_COLLECTION: 3
      COVERAGE: 1
EOF

cat  > config/selenium.yml << EOF
test:
  remote_url_firefox: http://selenium-firefox:4444/wd/hub
  remote_url_chrome: http://selenium-chrome:4444/wd/hub
  browser: chrome
EOF

ZONE="America/Phoenix"
TS=$(date +%Hh-%Mm-%F)

docker-compose build
docker-compose run --rm web bundle install
docker-compose run --rm web bundle exec rake db:create db:initial_setup canvas:compile_assets_dev
docker-compose run -e "RAILS_ENV=test" --rm web bundle exec rake db:create
docker-compose run -e "RAILS_ENV=test" --rm web bundle exec rake db:migrate
docker-compose up -d
docker-compose run -d web bundle exec rspec spec --format documentation  --out test_results/rspec-$TS.md
