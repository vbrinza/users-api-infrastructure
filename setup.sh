#!/bin/bash
echo "Enable IAM"
gcloud projects create $1
gcloud iam service-accounts create $1 --project $1
gcloud iam service-accounts keys create gce-$1-key.json --iam-account=$1@$1.iam.gserviceaccount.com --project $1
gcloud projects add-iam-policy-binding $1 --member="serviceAccount:$1@$1.iam.gserviceaccount.com" --role='roles/editor' --project $1

echo "Reconfigure the kubectl with new cluster data"
gcloud config set project $1

echo "Link billing to the account"
ACC_ID=`gcloud alpha billing accounts list|awk '{print $1}'|grep -v ID`
echo $ACC_ID
gcloud alpha billing projects link $1 --billing-account $ACC_ID

echo "Enable API's"
echo "Enable Google Cloud SQL API"
gcloud services enable sql-component.googleapis.com
echo "Enable Google Cloud SQL ADMIN"
gcloud services enable sqladmin.googleapis.com
echo "Enable Google Cloud Compute API"
gcloud services enable compute.googleapis.com
echo "Enable Google Cloud Kubernetes API"
gcloud services enable container.googleapis.com

echo "Please enter the password you want to use for the Kubernetes cluster:"
read -sr K8S_PASSWORD_INPUT

echo "Setup Google Cloud Kubernetes"
cd kubernetes \
&& terraform init \
&& terraform plan -var "project=$1" -var "cluster_name=$1" -var "username=$1" -var "password=$K8S_PASSWORD_INPUT" \
&& terraform apply -var "project=$1" -var "cluster_name=$1" -var "username=$1" -var "password=$K8S_PASSWORD_INPUT"

echo "Deploy MySQL on Google Cloud SQL"
echo "Please enter the Cloud SQL user password"
read -sr CLOUD_SQL_PASSWORD_INPUT
cd ../mysql && terraform init \
&& terraform plan  -var "name=$1" -var "project=$1" -var "db_name=$1" -var "user_name=$1" -var "user_password=$CLOUD_SQL_PASSWORD_INPUT" \
&& terraform apply  -var "name=$1" -var "project=$1" -var "db_name=$1" -var "user_name=$1" -var "user_password=$CLOUD_SQL_PASSWORD_INPUT"

echo "Addapt the application template"
cat <<EOF > ../application_deploy/app_deployment.yml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: birthday-api
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: birthday-api
    spec:
      containers:
      - name: birthday-api
        image: quay.io/pithagora/birthday-api
        env:
        - name: SQLALCHEMY_DATABASE_URI
          value: mysql+pymysql://$1:$CLOUD_SQL_PASSWORD_INPUT@/$1?unix_socket=/cloudsql/$1:europe-west1:$1
        ports:
        - containerPort: 5000
      - image: b.gcr.io/cloudsql-docker/gce-proxy:1.05
        name: cloudsql-proxy
        command: ["/cloud_sql_proxy", "--dir=/cloudsql",
                  "-instances=$1:europe-west1:$1=tcp:3306",
                  "-credential_file=/secrets/cloudsql/credentials.json"]
        volumeMounts:
          - name: cloudsql-oauth-credentials
            mountPath: /secrets/cloudsql
            readOnly: true
          - name: ssl-certs
            mountPath: /etc/ssl/certs
      volumes:
        - name: cloudsql-oauth-credentials
          secret:
            secretName: cloudsql-oauth-credentials
        - name: ssl-certs
          hostPath:
            path: /etc/ssl/certs
EOF

echo "Gather Kubernetes Credentials"
sleep 60
gcloud container clusters get-credentials $1 --zone europe-west1-b

echo "Add secrets"
sleep 60
cd .. && kubectl create secret generic cloudsql-oauth-credentials --from-file=credentials.json=gce-$1-key.json

echo "Deploy the application"
kubectl apply -f application_deploy/app_deployment.yml
sleep 60
echo "Expose application"
kubectl apply -f application_deploy/service.yml
