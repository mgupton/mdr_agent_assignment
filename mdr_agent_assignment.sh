#!/bin/bash
#
# This script collects information on agents 
# deployed for the Alert Logic MDR solution across all
# deployments under a single customer account (CID) and
# outputs a CSV file that gives the agent name, the
# IDS sensor it is assigned to and the deployment name
# that it belongs to.
#
# To use this script pass it the Alert Logic customer ID (CID) as
# the one and only parameter. And provide the user name and password
# use to access the Alert Logic console.
#
# Dependencies:
# 
# - curl
# - jq, https://stedolan.github.io/jq/ 
#
#
# Usage:
# mdr_agent_assignment <cid>
#
#
# Sample Output:
#
# ./mdr_agent_assignment.sh $cid
# Username: *****
# Password: *****
# Getting asset data.
# Getting agent data.
# Getting appliance data.
# Getting deployment data.
# Getting assignment data.
# Agent assignment info is in the file:  ./tmp.GbnuNB9Xxu/agent_assignment.csv
#
# agent,appliance,deployment
# "i-0017320e84731ec21","i-05daabe56045a9330","Development"
# "i-001c6bdc07b87967a","i-05daabe56045a9330","Development"
# "i-002b6700178df1820","i-05daabe56045a9330","Development"
#

read -p "Username: " user
read -sp "Password: " pass
echo ""

working_dir=$(mktemp -d -p ./)

export auth_token=$(curl -s -X POST -u "${user}:${pass}" https://api.cloudinsight.alertlogic.com/aims/v1/authenticate | jq -r ". | .authentication.token")
unset pass

echo "Getting asset data."
curl -s -X GET -H "x-aims-auth-token: $auth_token" "https://api.cloudinsight.alertlogic.com/assets_query/v1/$1/assets" > $working_dir/assets.json

echo "Getting agent data."
jq -r '.assets[][] | select(.type == "agent") | [.name, .scope_identity_assigned_to, .deployment_id] | @csv' $working_dir/assets.json | sort -t "," -k 2,2 > $working_dir/agents.csv

echo "Getting appliance data."
jq -r '.assets[][] | select(.type == "appliance") | [.scope_identity_host_uuid, .name] | @csv' $working_dir/assets.json | sort -t "," -k 2,2 > $working_dir/appliances.csv

echo "Getting deployment data."
curl -s -X GET -H "x-aims-auth-token: $auth_token" "https://api.cloudinsight.alertlogic.com/environments/v1/$cid" > $working_dir/deployments.json
jq -r '.environments[] | [.id, .name] | @csv' $working_dir/deployments.json | sort -t "," -k 1,1 > $working_dir/deployments.csv

echo "Getting assignment data."
echo "agent,appliance,deployment" > $working_dir/agent_assignment.csv
join -o 1.1,2.2,1.3 -t , -1 2 -2 1 <(sort -t "," -k 2,2 $working_dir/agents.csv) <(sort -t "," -k 1,1 $working_dir/appliances.csv) | sort -t "," -k 3,3 | join -t , -o 1.1,1.2,2.2 -1 3 -2 1 - $working_dir/deployments.csv >> $working_dir/agent_assignment.csv

echo "Agent assignment info is in the file: " $working_dir/agent_assignment.csv
