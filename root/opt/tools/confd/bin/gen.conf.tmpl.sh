#!/usr/bin/env bash

KAFKA_HEAP_OPTS=${JVMFLAGS:-"-Xmx1G -Xms1G"}
KAFKA_ADVERTISE_PORT=${KAFKA_ADVERTISE_PORT:-"9092"}
KAFKA_DELETE_TOPICS=${KAFKA_DELETE_TOPICS:-"false"}
KAFKA_LISTENER=${KAFKA_LISTENER:-"PLAINTEXT://0.0.0.0:"${KAFKA_ADVERTISE_PORT}}
KAFKA_LOG_DIRS=${KAFKA_LOG_DIRS:-${SERVICE_HOME}"/logs"}
KAFKA_LOG_FILE=${KAFKA_LOG_FILE:-${KAFKA_LOG_DIRS}"/kafkaServer.out"}
KAFKA_LOG_RETENTION_HOURS=${KAFKA_LOG_RETENTION_HOURS:-"168"}
KAFKA_OFFSET_RETENTION_MINUTES=${KAFKA_OFFSET_RETENTION_MINUTES:-"1440"}
KAFKA_NUM_PARTITIONS=${KAFKA_NUM_PARTITIONS:-"1"}
KAFKA_ZK_PORT=${KAFKA_ZK_PORT:-"2181"}
KAFKA_EXT_IP=${KAFKA_EXT_IP:-""}
KAFKA_SSL=${KAFKA_SSL:-"false"}
KAFKA_KEYSTORE_PASSWORD=${KAFKA_KEYSTORE_PASSWORD:-""}
KAFKA_SSL_CONFIG=""
KAFKA_SSL_LISTENER=""
KAFKA_SSL_AUTH=${KAFKA_SSL_AUTH:-"none"}

if [ "$KAFKA_SSL" == "true" ]; then
    KAFKA_SSL_CONFIG="
        ssl.keystore.location=/opt/kafka/ssl/kafka.server.keystore.jks
        ssl.keystore.password=${KAFKA_KEYSTORE_PASSWORD}
        ssl.key.password=${KAFKA_KEYSTORE_PASSWORD}
        ssl.truststore.location=/opt/kafka/ssl/kafka.server.truststore.jks
        ssl.truststore.password=${KAFKA_KEYSTORE_PASSWORD}
        ssl.keystore.type=JKS
        ssl.truststore.type=JKS
        ssl.enabled.protocols =TLSv1.2,TLSv1.1,TLSv1
        ssl.client.auth = ${KAFKA_SSL_AUTH}
    "
    KAFKA_SSL_LISTENER=",SSL://${HOSTNAME}:9093"
fi

if [ "$ADVERTISE_PUB_IP" == "true" ]; then
    KAFKA_ADVERTISE_IP='{{getv "/self/host/agent_ip"}}'
else
    KAFKA_ADVERTISE_IP='{{getv "/self/container/primary_ip"}}'
fi
KAFKA_ADVERTISE_LISTENER=${KAFKA_ADVERTISE_LISTENER:-"PLAINTEXT://"${KAFKA_ADVERTISE_IP}":"${KAFKA_ADVERTISE_PORT}}



cat << EOF > ${SERVICE_VOLUME}/confd/etc/conf.d/server.properties.toml
[template]
src = "server.properties.tmpl"
dest = "${SERVICE_HOME}/config/server.properties"
owner = "${SERVICE_USER}"
mode = "0644"
keys = [
  "/self",
  "/stacks",
]

reload_cmd = "${SERVICE_HOME}/bin/kafka-service.sh restart"
EOF

cat << EOF > ${SERVICE_VOLUME}/confd/etc/templates/server.properties.tmpl
############################# Server Basics #############################
broker.id={{getv "/self/container/service_index"}}
############################# Socket Server Settings #############################
listeners=${KAFKA_LISTENER}${KAFKA_SSL_LISTENER}
advertised.listeners=${KAFKA_ADVERTISE_LISTENER}${KAFKA_SSL_LISTENER}
${KAFKA_SSL_CONFIG}
num.network.threads=3
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600
############################# Log Basics #############################
log.dirs=${KAFKA_LOG_DIRS}
num.partitions=${KAFKA_NUM_PARTITIONS}
num.recovery.threads.per.data.dir=1
delete.topic.enable=${KAFKA_DELETE_TOPICS}
############################# Log Flush Policy #############################
#log.flush.interval.messages=10000
#log.flush.interval.ms=1000
############################# Log Retention Policy #############################
log.retention.hours=${KAFKA_LOG_RETENTION_HOURS}
#log.retention.bytes=1073741824
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000
log.cleaner.enable=true
############################# Offset Retention #############################
offset.retention.minutes=${KAFKA_OFFSET_RETENTION_MINUTES}
############################# Connect Policy #############################{{ \$zk_link := split (getenv "ZK_SERVICE") "/" }}{{\$zk_stack := index \$zk_link 0}}{{ \$zk_service := index \$zk_link 1}} 
zookeeper.connect={{range \$i, \$e := ls (printf "/stacks/%s/services/%s/containers" \$zk_stack \$zk_service)}}{{if \$i}},{{end}}{{getv (printf "/stacks/%s/services/%s/containers/%s/primary_ip" \$zk_stack \$zk_service \$e)}}:${KAFKA_ZK_PORT}{{end}}
zookeeper.connection.timeout.ms=6000
EOF
