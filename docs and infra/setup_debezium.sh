#!/bin/sh

echo 'Waiting for Debezium API to be ready...'
while ! curl -s http://debezium-connect:8083/connectors; do
  sleep 5;
done;
echo 'Debezium is running! Injecting Postgres Connector Config...'
curl -i -X POST -H "Accept:application/json" -H "Content-Type:application/json" http://debezium-connect:8083/connectors/ -d '{
  "name": "processor-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "crawler-pg-db",
    "database.port": "5432",
    "database.user": "user",
    "database.password": "password",
    "database.dbname": "crawler_db",
    "database.server.name": "processor_server",
    "topic.prefix": "postgres",
    "table.include.list": "public.crawl_records",
    "plugin.name": "pgoutput"
  }
}'
