
#Once the webhook is ready we will deploy our webhook in the cluster as a deployment and expose it via a service.

#DEPLOYMENT NAME: validation-webhook
#NAMESPACE:       custom-webhooks

######################################################################
## Set the default values
######################################################################
export DOMAIN=mutation-webhook
export NAMESPACE=custom-webhooks
export KUBE_API_SERVER_NAMESPACE=kube-system
export VALIDITY_DAYS=3650
export KUBECONFIG_PATH_MASTER_NODE=/etc/kubernetes/webhook-pki/${DOMAIN}
#######################################################################
## In Most cases, you would not have to modify anything below this line
## If you know what you are doing, feel free to modify.
#######################################################################

#create namespace


kubectl create ns "${NAMESPACE}"


#Generate the CA KEY
openssl genrsa -out ${DOMAIN}_CA.key 4096 &>/dev/null
openssl req -new -x509 -days "${VALIDITY_DAYS}" -key ${DOMAIN}_CA.key -subj "/CN=${DOMAIN}.${NAMESPACE}.svc" -out ${DOMAIN}_CA.crt 


# Generate the CSR
openssl req -newkey rsa:4096 -nodes -keyout ${DOMAIN}.key -subj "/CN=${DOMAIN}.${NAMESPACE}.svc" -out ${DOMAIN}.csr 

#sign the webhook's cert by ca:
openssl x509 -req -extfile <(printf "subjectAltName=DNS:${DOMAIN}.${NAMESPACE}.svc,DNS:${DOMAIN}.${NAMESPACE}.svc.cluster.local") -days "${VALIDITY_DAYS}" -in ${DOMAIN}.csr -CA ${DOMAIN}_CA.crt -CAkey ${DOMAIN}_CA.key -CAcreateserial -out ${DOMAIN}.crt &>/dev/null


#kubectl create secret generic ${DOMAIN}-webhook-secret -n ${NAMESPACE} --from-file="${DOMAIN}.crt" --from-file="${DOMAIN}.key"
kubectl create secret tls ${DOMAIN}-webhook-secret -n ${NAMESPACE} --cert "${DOMAIN}.crt" --key "${DOMAIN}.key"

# Generate the Kubeconfig file for the webhook service that webhook would use to authenticate to API Server.

cat <<EOF | tee ${DOMAIN}_kubeconfig.yml &>/dev/null
apiVersion: v1
kind: Config
users:
- name: "${DOMAIN}.${NAMESPACE}.svc"
  user:
    client-certificate-data: "$(cat ${DOMAIN}.crt|base64 |tr -d '\n')"
    client-key-data: "$(cat ${DOMAIN}.key|base64 |tr -d '\n')"
EOF


# Generate the Admission Configuration
#This basically provide information ,Type of the webhook, its kubeconfig path
#to the api server
# 


cat << EOF |tee ${DOMAIN}_AdmissionConfiguration.yml &>/dev/null
apiVersion: apiserver.config.k8s.io/v1
kind: AdmissionConfiguration
plugins:
- name: MutatingAdmissionWebhook
  configuration:
    apiVersion: apiserver.config.k8s.io/v1
    kind: WebhookAdmissionConfiguration
    kubeConfigFile: "${KUBECONFIG_PATH_MASTER_NODE}/${DOMAIN}/${DOMAIN}_kubeconfig.yml"
EOF



cat << EOF | tee ${DOMAIN}_MutatingWebhookConfiguration.yml &>/dev/null
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: ${DOMAIN}
webhooks:
- admissionReviewVersions:
  - v1
  clientConfig:
    caBundle: "$(cat ${DOMAIN}_CA.crt  |base64 -w0)" 
    service:
      name: ${DOMAIN}
      namespace: ${NAMESPACE}
      path: /mutate/deployments/replicas              # send the request to the  webhook at this path. Eg: example.com//mutate/deployments   
      port: 443
  failurePolicy: Fail                        # if the webhook is unavailable, decision is to fail. 
  matchPolicy: Equivalent
  name: ${DOMAIN}.${NAMESPACE}.svc
  namespaceSelector:
    matchLabels:
      env: prod                              # this webhook will called only when the operations are done at the namespaces with following labels. use {} for all.
  objectSelector: {}
  rules:
  - apiGroups:
    - apps
    apiVersions:
    - v1
    operations:           # send the request to webhook when the following operation is requested. 
    - CREATE
    resources:
    - deployments         # The validation webhook is valid for the following type of resources.
    # * means:            for all namespaced and cluster scoped resources
    # Namespaced means:   for all namespaced resources
    # Cluster means:      for all the clustered scoped resources
    scope: Namespaced
  sideEffects: None
  timeoutSeconds: 5
EOF

# print the instructions

#create the config-map for the admission configuration and kubeconfig file

#kubectl create configmap ${DOMAIN}-webhook-configmap -n "${KUBE_API_SERVER_NAMESPACE:-kube-system}" --from-file=${DOMAIN}_kubeconfig.yml --from-file=${DOMAIN}_AdmissionConfiguration.yml

#copy the following files into the Master node under the directory mentioned below

echo "------------------ Action on the Master Node --------------------------------"
echo "scp ${DOMAIN}_kubeconfig.yml <MASTER-NODE-IP>"
echo "sudo mkdir -p ${KUBECONFIG_PATH_MASTER_NODE}"
echo "cp ${DOMAIN}_kubeconfig.yml ${KUBECONFIG_PATH_MASTER_NODE}"
echo "cp ${DOMAIN}_AdmissionConfiguration.yml ${KUBECONFIG_PATH_MASTER_NODE}"
echo "-----------------------------------------------------------------------------"

echo "##1) Add the following Volume in the webhook pod under the volume list:

  - name: ${DOMAIN}-admission-plugins-secret
    secret:
      secretName: "${DOMAIN}-webhook-secret"
      optional: false

##2) Add the following volume in the webhook pod under volumeMounts

  - mountPath: "${KUBECONFIG_PATH_MASTER_NODE}"
    name: ${DOMAIN}-admission-plugins-secret
    readOnly: true
 
----------------------------------------------------------------------------------------------------------

##3) Add the following volume in the kube-api server pod under the volume list:
 
  - name: ${DOMAIN}-admission-plugins-config
    hostPath:
      path: "${KUBECONFIG_PATH_MASTER_NODE}/${DOMAIN}"

##4) Add the following volume in the VolumeMounts of the kube-api server pod:

    - mountPath: "${KUBECONFIG_PATH_MASTER_NODE}/${DOMAIN}"
      name: ${DOMAIN}-admission-plugins-config
      readOnly: true
"
echo "---------------------------------Enable this flag in the API Server---------------------------------"
echo " --admission-control-config-file=${KUBECONFIG_PATH_MASTER_NODE}/${DOMAIN}_AdmissionConfiguration.yml"
echo "----------------------------------------------------------------------------------------------------"

echo "----------------------------------------------------------------------------------------------------"




docker build -t mutate-deployment:latest .

docker tag mutate-deployment technekey/kubernetes-webhooks:latest

docker push technekey/kubernetes-webhooks:latest

