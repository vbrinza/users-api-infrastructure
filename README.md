## Prerequisites:

1. gcloud -v
Google Cloud SDK 222.0.0
alpha 2018.09.04
beta 2018.07.16
bq 2.0.36
core 2018.10.19
gsutil 4.34
kubectl 2018.09.17

2. Terraform v0.11.10

## Steps to setup:

1. authenticate with gcloud into your Google account.
2. run
```
bash setup.sh <project_name>
```
3. It will ask for the Kubernetes cluster password. Please use one of minimum 17 characters.
4. It will ask for the Cloud SQL password. Please use one of minimum 17 characters.
