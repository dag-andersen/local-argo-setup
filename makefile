cluster-name ?= "local-argo-setup"
port ?= 8080
path-to-repo ?= ../cloud-infra-deployment

# Kind -------

create: 
	@echo "Setting up cluster..."
	@kind create cluster --name $(cluster-name) --wait 5m
	@kubectl config delete-context $(cluster-name) || true
	@kubectl config rename-context $$(kubectl config current-context) $(cluster-name)

create-with-ingress:
	@echo "Setting up cluster with ingress..."
	@kind create cluster --name $(cluster-name) --wait 5m --config ./kind/kind-cluster.yml
	@kubectl config delete-context $(cluster-name) || true
	@kubectl config rename-context $$(kubectl config current-context) $(cluster-name)
	@gum spin -- kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	@gum spin --title "Sleeping" -- sleep 5
	@gum spin --title "waiting for ingress" -- kubectl wait -n ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=150s
	@gum spin -- kubectl apply -f ./kind/test-setup.yml
	@gum spin sleep 10
	@echo "Testing if ingress is working..."
	curl localhost/test
	@echo

delete:
	@kind delete cluster --name $(cluster-name)
	@kubectl config delete-context $(cluster-name) && gum spin sleep 3 || true

# Argo -------

argo-install: context
	@echo "ArgoCD Install..."
	@kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@echo "Waiting for ArgoCD to get ready..."
	@while ! kubectl wait -A --for=condition=ready pod -l "app.kubernetes.io/name=argocd-server" --timeout=300s; do echo "Waiting for ArgoCD to get ready..." && sleep 10; done
	@sleep 2
	@echo

argo-login: context
	@echo "ArgoCD Login..."
# echo "killing all port-forwarding" && pkill -f "port-forward" || true
# kubectl port-forward svc/argocd-server --pod-running-timeout=100m0s -n argocd $(port):443 &>/dev/null &
	@argocd login --port-forward --insecure --port-forward-namespace argocd --username=admin --password=$$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo)
	@export ARGOCD_OPTS='--port-forward-namespace argocd' 
	@echo

argo-ui-localhost-port-forward: context argo-login-credentials
	kubectl get nodes &>/dev/null
	@echo "killing all port-forwarding" && pkill -f "port-forward" || true
	kubectl port-forward svc/argocd-server --pod-running-timeout=60m0s -n argocd $(port):443 &>/dev/null &
	@open http://localhost:$(port)
	@echo

argo-login-credentials: context
	@echo "username: admin, password: $$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo)"	

# Bootstrap -------

argo-bootstrap-creds:
	@echo "Bootstrapping credentials..."
	@kubectl create namespace argocd 			--dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -f ./creds/repo-creds.yml

argo-bootstrap-apps:
	kubectl apply -f applications.yml
	@kubectl apply -f $(path-to-repo)/argo-bootstrap/local/bootstrap.yml

# Utils -------

install-tools:
	@brew install kind
	@brew install kubectl
	@brew install argocd
	@brew install kustomize
	@brew install gum

context:
	@kubectl config use-context $(cluster-name)
	@echo

update:
	rm apps.txt || true
	rm paths.txt || true
	rm apps.pre || true
	argocd app list >> apps.pre
	cat apps.pre | awk '{if (NR!=1) print $$1;}' | xargs -I {} argocd app set {} --sync-policy=none
	cat apps.pre | grep -v "pplication-bootstrap" | awk '{if (NR!=1) print $$1;}' | xargs -I {} echo {} >> apps.txt
	cat apps.pre | grep -v "pplication-bootstrap" | awk '{if (NR!=1) print $$1;}' | xargs -I {} argocd app get {} | grep "Path" | awk '{print $$2;}' >> paths.txt
	sleep 3
	for i in {1..10}; do \
		app=$$(sed -n "$$i"p apps.txt); \
		path=$$(sed -n "$$i"p paths.txt); \
		if [ ! -z "$$app" ] && [ ! -z "$$path" ]; then \
			echo "Removing sync policy from app: $$app"; \
			echo "App: $$app" - Path: $(path-to-repo)/$$path; \
			argocd app sync $$app --local=$(path-to-repo)/$$path; \
		fi; \
	done
	rm apps.txt || true
	rm paths.txt || true
	rm apps.pre || true

replace-all-hostnames:
	@echo "Replacing all hostnames..."
	@find $(path-to-repo) -name "*.yml" -exec sed -i '' 's/dagandersen.com/localhost/g' {} \;

everything: create-with-ingress argo-install argo-login argo-ui-localhost-port-forward argo-bootstrap-creds argo-bootstrap-apps replace-all-hostnames
