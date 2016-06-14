#!/bin/bash

IMAGE_ID="mysql:5.7.13"
CONTAINER_NAME="my-query-runner"
SQL_FILE="test-queries.sql"
MY_USERNAME="test"
MY_PASSWORD="test"
MY_DATABASE="test"

docker kill $CONTAINER_NAME
docker rm $CONTAINER_NAME

docker run \
  -e MYSQL_ROOT_PASSWORD=$MY_PASSWORD \
  -e MYSQL_USER=$MY_USERNAME \
  -e MYSQL_PASSWORD=$MY_PASSWORD \
  -e MYSQL_DATABASE=$MY_DATABASE \
  --name=$CONTAINER_NAME \
  -P -d $IMAGE_ID

MY_HOST="localhost"
MY_PORT=`docker inspect -f '{{(index (index .NetworkSettings.Ports "5432/tcp") 0).HostPort}}' ${CONTAINER_NAME}`

echo "host: ${MY_HOST}"
echo "port: ${MY_PORT}"
echo "user: ${MY_USERNAME}"
echo "pass: ${MY_PASSWORD}"
echo "  db: ${MY_DATABASE}"


# Wait for the database to come online
coffee node_modules/wait-for-mysql/src/index.coffee \
  --host=$MY_HOST \
  --port=$MY_PORT \
  --username=$MY_USERNAME \
  --password=$MY_PASSWORD \
  --database=$MY_DATABASE

# Test the query runner
coffee src/index.coffee \
  --schema=mysql \
  --host=$MY_HOST \
  --port=$MY_PORT \
  --username=$MY_USERNAME \
  --password=$MY_PASSWORD \
  --database=$MY_DATABASE \
  test-queries.sql

docker kill $CONTAINER_NAME
docker rm $CONTAINER_NAME

