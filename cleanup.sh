#!/bin/bash
echo "Delete project with everything inside"
gcloud projects delete $1

rm -rf kubernetes/.terraform
rm -rf kubernetes/terraform.*

rm -rf mysql/.terraform
rm -rf mysql/terraform.*

rm gce-$1-key.json
