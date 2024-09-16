GCP_ACCOUNT := ppdencolorado@gmail.com 
GCP_PROJECT := pacp
GCP_COMPUTE_REGION := us-central1
GCP_COMPUTE_ZONE := ${GCP_COMPUTE_REGION}-a
GKE_VERSION := "1.29.5-gke.1091002"
CLUSTER_NAME := pacp-mc-control-plane
CLUSTER_NETWORK := default

.PHONY: setup
setup: setup-gcloud setup-kubectl

.PHONY: setup-gcloud
setup-gcloud:
	gcloud config set account ${GCP_ACCOUNT}
	gcloud config set project ${GCP_PROJECT}
	gcloud config set compute/region ${GCP_COMPUTE_REGION}
	gcloud config set compute/zone ${GCP_COMPUTE_ZONE}
	gcloud components install gke-gcloud-auth-plugin --quiet

.PHONY: setup-kubectl
setup-kubectl: install-krew
	kubectl krew install minio
	kubectl krew install preflight
	kubectl krew install support-bundle

.PHONY: install-krew
install-krew:
	(set -x; cd "$(mktemp -d)" && \
	OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
	ARCH="$(uname -m)" && \
	KREW="krew-${OS}_${ARCH}" && \
	curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" && \
	tar zxvf "${KREW}.tar.gz" && \
	./"${KREW}" install krew)
	export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

.PHONY: update-gcloud
update-gcloud:
	gcloud components update --quiet
	gcloud components install gke-gcloud-auth-plugin --quiet

.PHONY: setup-cluster
setup-cluster:
	gcloud container --project "${GCP_PROJECT}" clusters create "${CLUSTER_NAME}" --region "${GCP_COMPUTE_REGION}" --no-enable-basic-auth --cluster-version ${GKE_VERSION} --release-channel "regular" --machine-type "e2-standard-16" --image-type "COS_CONTAINERD" --disk-type "pd-balanced" --disk-size "100" --metadata disable-legacy-endpoints=true --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --max-pods-per-node "110" --num-nodes "4" --logging=SYSTEM,WORKLOAD --monitoring=SYSTEM --enable-ip-alias --network "projects/${GCP_PROJECT}/global/networks/${CLUSTER_NETWORK}" --subnetwork "projects/${GCP_PROJECT}/regions/${GCP_COMPUTE_REGION}/subnetworks/${CLUSTER_NETWORK}" --no-enable-intra-node-visibility --default-max-pods-per-node "110" --no-enable-master-authorized-networks --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver --enable-autoupgrade --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --enable-shielded-nodes --node-locations "${GCP_COMPUTE_REGION}-a","${GCP_COMPUTE_REGION}-b","${GCP_COMPUTE_REGION}-c"

.PHONY: get-credentials
get-credentials:
	gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${GCP_COMPUTE_REGION} --project ${GCP_PROJECT} --quiet

.PHONY: clean
clean: clean-cluster

.PHONY: clean-cluster
clean-cluster:
	gcloud container clusters delete ${CLUSTER_NAME} --location ${GCP_COMPUTE_REGION} --quiet

.PHONY: set-context
set-context:
	kubectl config use-context gke_${GCP_PROJECT}_${GCP_COMPUTE_REGION}_${CLUSTER_NAME}

.PHONY: install-cert-manager
install-cert-manager:
	helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.13.3 --set installCRDs=true

.PHONY: install-minio
install-minio:
	kubectl minio init

.PHONY: install-mission-control
install-mission-control:
	kubectl kots install mission-control
