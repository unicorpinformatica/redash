#!/usr/bin/env bash
# This script setups dockerized Redash on Ubuntu 18.04.
set -eu

REDASH_BASE_PATH=/opt/redash

create_config() {
    touch .env

    COOKIE_SECRET=$(pwgen -1s 32)
    SECRET_KEY=$(pwgen -1s 32)
    POSTGRES_PASSWORD=$(pwgen -1s 32)
    REDASH_DATABASE_URL="postgresql://postgres:${POSTGRES_PASSWORD}@postgres/postgres"

    echo "PYTHONUNBUFFERED=0" >> .env
    echo "REDASH_LOG_LEVEL=INFO" >> .env
    echo "REDASH_REDIS_URL=redis://redis:6379/0" >> .env
    echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" >> .env
    echo "REDASH_COOKIE_SECRET=$COOKIE_SECRET" >> .env
    echo "REDASH_SECRET_KEY=$SECRET_KEY" >> .env
    echo "REDASH_DATABASE_URL=$REDASH_DATABASE_URL" >> .env
}

setup_compose() {
    sudo docker-compose run --rm server create_db
    sudo docker-compose up -d
}

# install_docker
# create_directories
create_config
setup_compose