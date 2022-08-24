#!/bin/bash

# Set variables based on input arguments
myHostname="YOUR_DOMAIN_NAME"
mySharedSecret="SHARED_SECRET_FROM_TERRAFORM"
myAPIURL="LAMBDA_PUBLIC_URL_FROM_TERRAFORM"

# Call the API in get mode to get the IP address
myIP=`curl -q -s  "https://$myAPIURL?mode=get" | egrep -o '[0-9\.]+'`
# Build the hashed token
myHash=`echo -n $myIP$myHostname$mySharedSecret | shasum -a 256 | awk '{print $1}'`
# Call the API in set mode to update Route 53
curl -q -s "https://$myAPIURL?mode=set&hostname=$myHostname&hash=$myHash"
echo