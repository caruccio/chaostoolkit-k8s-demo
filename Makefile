SHELL := /bin/bash
NAMESPACE := chaosdemo
IMAGE_REPO := getupcloud

all: images push deploy

help:
	@echo "Usage: make [target...]"
	@echo
	@echo "Targets:"
	@echo "   images:           Build docker images"
	@echo "   push:             Push docker images to dockerhub"
	@echo "   gen-certs:        Generate SSL certificates and CA"
	@echo "   certs.yaml:       Create configMap file with SSL certificates and CA"
	@echo "   chaos:            Execute \`chaos\` command"
	@echo "   deploy:           Deploy demo services"
	@echo "   undeploy:         Remove deployed demo services"
	@echo "   set-expired-cert: Update backend service with expired certificate"
	@echo "   set-valid-cert:   Update backend service with valid certificate"
	@echo "   clean:            Remove local and remote resources (except docker hub images)"

chaostoolkit-documentation-code:
	git clone https://github.com/caruccio/chaostoolkit-documentation-code.git

images: chaostoolkit-documentation-code
	docker build --no-cache . -t $(IMAGE_REPO)/city-sunset:latest -f Dockerfile.app
	docker build --no-cache . -t $(IMAGE_REPO)/chaos:latest -f Dockerfile

push:
	docker push $(IMAGE_REPO)/city-sunset:latest
	#docker push $(IMAGE_REPO)/chaos:latest

chaos:
	docker run -it --rm -v $(PWD)/experiments:/experiments chaos:latest chaos run /experiments/demo.json

deploy: certs.yaml
	kubectl -n $(NAMESPACE) create -f certs.yaml
	kubectl -n $(NAMESPACE) create -f sunset.yaml

undeploy:
	kubectl -n $(NAMESPACE) delete -f certs.yaml || true
	kubectl -n $(NAMESPACE) delete -f sunset.yaml || true

redeploy: undeploy deploy

sunset.yaml:
	kubectl run backend-astre --namespace $(NAMESPACE) --dry-run -o yaml \
	    --image=$(IMAGE_REPO)/city-sunset:latest \
	    --image-pull-policy=Always \
	    --env=SSL_KEY=/certs/backend-astre-valid.key \
	    --env=SSL_CRT=/certs/backend-astre-valid.crt \
	    --port=8444 --expose \
	    --command -- python3.5 astre.py > sunset.yaml
	
	kubectl run frontend-sunset --namespace $(NAMESPACE) --dry-run -o yaml \
	    --image=$(IMAGE_REPO)/city-sunset:latest \
	    --image-pull-policy=Always \
	    --env=SSL_KEY=/certs/frontend-sunset-valid.key \
	    --env=SSL_CRT=/certs/frontend-sunset-valid.crt \
	    --env=ASTRE_SERVICE=backend-astre \
	    --env=ASTRE_SSL_CRT=/certs/ca-bundle-backend-astre-valid.crt \
	    --port=8443 --expose \
	    --command -- python3.5 sunset.py >> sunset.yaml

.PHONY: gen-certs
gen-certs:
	./gen-certs.sh frontend-sunset.$(NAMESPACE).svc 3560 frontend-sunset
	./gen-certs.sh backend-astre.$(NAMESPACE).svc 3560 backend-astre-valid
	read -p "Change host clock to 2 days ago and press ENTER..."
	./gen-certs.sh backend-astre.$(NAMESPACE).svc 1 backend-astre-expired
	read -p "Change clock time back to normal and press ENTER..."
	ls -la certs/*.{crt,key}

.PHONY: certs.yaml
certs.yaml:
	kubectl -n $(NAMESPACE) create configmap certs \
	    --from-file=certs/ca.crt \
	    --from-file=certs/ca.key \
	    --from-file=certs/frontend-sunset.crt \
	    --from-file=certs/frontend-sunset.key \
	    --from-file=certs/backend-astre-valid.crt \
	    --from-file=certs/backend-astre-valid.key \
	    --from-file=certs/backend-astre-expired.crt \
	    --from-file=certs/backend-astre-expired.key \
	    --from-file=certs/ca-bundle-frontend-sunset.crt \
	    --from-file=certs/ca-bundle-backend-astre-valid.crt \
	    --from-file=certs/ca-bundle-backend-astre-expired.crt \
	    --dry-run -o yaml > $@

set-expired-cert:
	kubectl -n $(NAMESPACE) set env deployments/backend-astre \
	    SSL_CRT=/certs/backend-astre-expired.crt \
	    SSL_KEY=/certs/backend-astre-expired.key

set-valid-cert:
	kubectl -n $(NAMESPACE) set env deployments/backend-astre \
	    SSL_CRT=/certs/backend-astre-valid.crt \
	    SSL_KEY=/certs/backend-astre-valid.key

clean: undeploy
	docker rmi $(IMAGE_REPO)/city-sunset:latest $(IMAGE_REPO)/chaos:latest || true
	rm -rf certs.yaml certs/ chaostoolkit-documentation-code/
