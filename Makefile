.PHONY: init plan apply destroy configure test help

VAULT_PASS_FILE = $(CURDIR)/ansible/.vault_pass
VAULT_FILE      = $(CURDIR)/ansible/vault.yml
TF_DIR          = $(CURDIR)/terraform

vault_var = $(shell ansible-vault view $(VAULT_FILE) --vault-password-file $(VAULT_PASS_FILE) | grep "^$(1):" | awk '{print $$2}')

TOKEN_SECRET  = $(call vault_var,proxmox_token_secret)
TECH_PASS     = $(call vault_var,technitium_admin_password)
PROV_PASS     = $(call vault_var,provisioning_root_password)
SEARXNG_PASS  = $(call vault_var,searxng_root_password)
OPENCLAW_PASS = $(call vault_var,openclaw_root_password)
HAWKEYE_PASS  = $(call vault_var,hawkeye_root_password)
NTFY_PASS     = $(call vault_var,ntfy_root_password)

TF_FLAGS = \
  -var="proxmox_token_secret=$(TOKEN_SECRET)" \
  -var="technitium_admin_password=$(TECH_PASS)" \
  -var="provisioning_root_password=$(PROV_PASS)" \
  -var="searxng_root_password=$(SEARXNG_PASS)" \
  -var="openclaw_root_password=$(OPENCLAW_PASS)" \
  -var="hawkeye_root_password=$(HAWKEYE_PASS)" \
  -var="ntfy_root_password=$(NTFY_PASS)"

help:
	@echo "homelab IaC"
	@echo "  make init              initialize Terraform"
	@echo "  make plan              preview infrastructure changes"
	@echo "  make apply             create/update infrastructure + configure"
	@echo "  make configure         run Ansible only"
	@echo "  make configure-TARGET  configure specific host (e.g. configure-technitium)"
	@echo "  make destroy           destroy all managed infrastructure"
	@echo "  make test              verify services are reachable"

init:
	cd $(TF_DIR) && terraform init

import-%:
	cd $(TF_DIR) && terraform import $(TF_FLAGS) \
	  proxmox_virtual_environment_vm.$* proxmox/$(id)

import-lxc-%:
	cd $(TF_DIR) && terraform import $(TF_FLAGS) \
	  proxmox_virtual_environment_container.$* proxmox/$(id)

plan:
	cd $(TF_DIR) && terraform plan $(TF_FLAGS)

apply:
	cd $(TF_DIR) && terraform apply $(TF_FLAGS) -auto-approve
	$(MAKE) configure

configure:
	ansible-playbook -i $(CURDIR)/ansible/inventory.yml \
	  $(CURDIR)/ansible/site.yml \
	  --vault-password-file $(VAULT_PASS_FILE)

configure-%:
	ansible-playbook -i $(CURDIR)/ansible/inventory.yml \
	  $(CURDIR)/ansible/site.yml \
	  --limit $* \
	  --vault-password-file $(VAULT_PASS_FILE)
	ansible-playbook -i $(CURDIR)/ansible/inventory.yml \
	  $(CURDIR)/ansible/site.yml \
	  --limit technitium \
	  --vault-password-file $(VAULT_PASS_FILE) \
	  --tags technitium

destroy:
	cd $(TF_DIR) && terraform destroy $(TF_FLAGS) -auto-approve

test:
	@echo -n "Technitium HTTPS:    "; curl -sf https://technitium.snorp.dev:53443 > /dev/null && echo "OK" || echo "FAIL"
	@echo -n "Proxmox UI:          "; curl -sfk https://proxmox.snorp.dev:8006 > /dev/null && echo "OK" || echo "FAIL"
	@echo -n "Provisioning menu:   "; curl -sf http://provisioning.snorp.dev/boot.cfg > /dev/null && echo "OK" || echo "FAIL"
	@echo -n "Provisioner health:  "; curl -sf http://provisioning.snorp.dev:8080/health > /dev/null && echo "OK" || echo "FAIL"
	@echo -n "SearXNG:             "; curl -sf https://searx.snorp.dev/ > /dev/null && echo "OK" || echo "FAIL"
	@echo -n "OpenClaw UI:         "; curl -sfk https://openclaw.snorp.dev > /dev/null && echo "OK" || echo "FAIL"
	@echo -n "Grafana (Hawkeye):   "; curl -sf http://hawkeye.snorp.dev:3000/api/health > /dev/null && echo "OK" || echo "FAIL"
	@echo -n "Prometheus:          "; curl -sf http://hawkeye.snorp.dev:9090/-/healthy > /dev/null && echo "OK" || echo "FAIL"
	@echo -n "Alertmanager:        "; curl -sf http://hawkeye.snorp.dev:9093/-/healthy > /dev/null && echo "OK" || echo "FAIL"
	@echo -n "ntfy:                "; curl -sf http://ntfy.snorp.dev/v1/health > /dev/null && echo "OK" || echo "FAIL"
	@echo -n "DNS resolution:      "; nslookup proxmox.snorp.dev 192.168.8.104 > /dev/null 2>&1 && echo "OK" || echo "FAIL"