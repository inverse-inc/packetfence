#!/bin/bash

connector_id=$(cat /dev/urandom | tr -dc '[:alpha:]' | fold -w ${1:-40} | head -n 1)

echo "Connector ID: $connector_id"
echo "=================================================================="

echo "Please configure the connector in PacketFence and input the secret here:"
read secret

echo "=================================================================="

echo "Configuring connector with ID '$connector_id' and secret '$secret'"

echo "AUTH=$connector_id:$secret" > /etc/pfconnector-client.env
