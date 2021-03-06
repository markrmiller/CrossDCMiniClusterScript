#!/bin/bash

kafkaBase="https://archive.apache.org/dist/kafka/2.8.1"
solrBase="https://dlcdn.apache.org/lucene/solr/8.11.1"

kafka="kafka_2.12-2.8.1"
solr="solr-8.11.1"

if [ ! -d cluster ]
then
  mkdir cluster
fi

cd cluster || exit

if [ ! -f ${kafka}.tgz ]
then
  wget "${kafkaBase}/${kafka}.tgz"
fi

if [ ! -d ${kafka} ]
then
  tar -xvzf ${kafka}.tgz
fi

if [ ! -f ${solr}.tgz ]
then
  wget "${solrBase}/${solr}.tgz"
fi

if [ ! -d ${solr} ]
then
  tar -xvzf ${solr}.tgz
fi

(
  cd "${kafka}" || exit


bin/zookeeper-server-start.sh config/zookeeper.properties > ../kafka_zk.log &

bin/kafka-server-start.sh config/server.properties > ../kafka_server.log &

# for kafka 2.x zk port of 2181, for 3.x broker of 9093

# bin/kafka-topics.sh --create --topic my-kafka-topic --bootstrap-server localhost:9093 --partitions 3 --replication-factor 2

# bin/kafka-topics.sh --list --bootstrap-server localhost:9093

# bin/kafka-console-producer.sh --broker-list localhost:9093,localhost:9094,localhost:9095 --topic my-kafka-topic

# bin/kafka-console-consumer.sh --bootstrap-server localhost:9093 --topic my-kafka-topic --from-beginning

# bin/kafka-console-consumer.sh --bootstrap-server localhost:9093 --topic my-kafka-topic --from-beginning --group group2
)

(
  cd "${solr}" || exit

  bin/solr start -cloud > ../solr.log

  # for kafka 2.x, ZK should be on 2181 and so we should be reusing it here
  # for the moment we upload the config set used in crossdc-producer tests
  bin/solr zk upconfig -z 127.0.0.1:2181 -n crossdc -d ../../crossdc-producer/src/test/resources/configs/cloud-minimal

  bin/solr create -c collection1 -n crossdc

  bin/solr status
)

# need to go to lib folder - I can't believe there is no shared lib folder by default - crazy
mkdir "${solr}/server/solr/lib"
cp ../crossdc-commons/build/libs/crossdc-commons-*.jar "${solr}"/server/solr/lib
cp ../crossdc-producer/build/libs/crossdc-producer-*.jar "${solr}"/server/solr/lib

cp ../crossdc-consumer/build/distributions/crossdc-consumer-*.tar .

tar -xvf crossdc-consumer-*.tar
rm crossdc-consumer-*.tar

(
  cd crossdc-consumer* || exit
  CROSSDC_CONSUMER_OPTS="-Dlog4j2.configurationFile=../log4j2.xml -DbootstrapServers=127.0.0.1:2181 -DzkConnectString=127.0.0.1:2181 -DtopicName=crossdc" bin/crossdc-consumer > ../crossdc_consumer.log
)
