#!/bin/bash

IMAGE_ID="postgres:9.5.3"
CONTAINER_NAME="pg-query-runner"
SQL_FILE="test-queries.sql"
PG_USERNAME="test"
PG_PASSWORD="test"
PG_DATABASE="test"

docker kill $CONTAINER_NAME
docker rm $CONTAINER_NAME

docker run \
  -e POSTGRES_USER=$PG_USERNAME \
  -e POSTGRES_PASSWORD=$PG_PASSWORD \
  -e POSTGRES_DATABASE=$PG_DATABASE \
  --name=$CONTAINER_NAME \
  -P -d $IMAGE_ID

PG_HOST="localhost"
PG_PORT=`docker inspect -f '{{(index (index .NetworkSettings.Ports "5432/tcp") 0).HostPort}}' ${CONTAINER_NAME}`

echo "host: ${PG_HOST}"
echo "port: ${PG_PORT}"
echo "user: ${PG_USERNAME}"
echo "pass: ${PG_PASSWORD}"
echo "  db: ${PG_DATABASE}"


# Wait for the database to come online
coffee node_modules/wait-for-postgres/src/index.coffee \
  --host=$PG_HOST \
  --port=$PG_PORT \
  --username=$PG_USERNAME \
  --password=$PG_PASSWORD \
  --database=$PG_DATABASE

# Test the query runner
coffee src/index.coffee \
  --schema=postgres \
  --host=$PG_HOST \
  --port=$PG_PORT \
  --username=$PG_USERNAME \
  --password=$PG_PASSWORD \
  --database=$PG_DATABASE \
  test-queries.sql

docker kill $CONTAINER_NAME
docker rm $CONTAINER_NAME

