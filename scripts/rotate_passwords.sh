#!/bin/bash
# Save as ~/MyPrograms/homelab/scripts/rotate-passwords.sh
set -euo pipefail

VAULT_PASS_FILE="$(dirname "$0")/../ansible/.vault_pass"
VAULT_FILE="$(dirname "$0")/../ansible/vault.yml"

# Generate new passwords
TECH_PASS="Technitium$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9' | head -c8)!"
PROV_PASS="Provisioning$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9' | head -c8)!"
SEARXNG_PASS="Searx$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9' | head -c8)!"
OPENCLAW_PASS="Openclaw$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9' | head -c8)!"

echo "Generated new passwords. Applying..."

# Update Technitium password via API
OLD_TECH_PASS=$(ansible-vault view "$VAULT_FILE" \
  --vault-password-file "$VAULT_PASS_FILE" | \
  grep technitium_admin_password | awk '{print $2}' | tr -d '"')

TOKEN=$(curl -s -X POST "http://192.168.8.104:5380/api/user/login" \
  --data-urlencode "user=admin" \
  --data-urlencode "pass=$OLD_TECH_PASS" \
  -d "includeInfo=false" | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['token'])")

curl -s -X POST "http://192.168.8.104:5380/api/user/changePassword" \
  -d "token=$TOKEN" \
  --data-urlencode "password=$TECH_PASS" > /dev/null
echo "Technitium password updated"

# Update LXC root passwords via pct
ssh root@192.168.8.187 "echo 'root:$PROV_PASS' | pct exec 101 -- chpasswd"
echo "Provisioning LXC password updated"

ssh root@192.168.8.187 "echo 'root:$SEARXNG_PASS' | pct exec 102 -- chpasswd"
echo "SearXNG LXC password updated"

# Update OpenClaw VM root password
ssh root@192.168.8.140 "echo 'root:$OPENCLAW_PASS' | chpasswd"
echo "OpenClaw VM password updated"

# Update vault
CURRENT_VAULT=$(ansible-vault view "$VAULT_FILE" \
  --vault-password-file "$VAULT_PASS_FILE")

PROXMOX_TOKEN=$(echo "$CURRENT_VAULT" | grep proxmox_token_secret | awk '{print $2}' | tr -d '"')
SEARXNG_KEY=$(echo "$CURRENT_VAULT" | grep searxng_secret_key | awk '{print $2}' | tr -d '"')
DEPLOY_KEY=$(echo "$CURRENT_VAULT" | grep -A100 provisioning_deploy_key | tail -n +2)

cat > /tmp/vault_plain.yml << VAULTEOF
technitium_admin_password: "${TECH_PASS}"
proxmox_token_secret: "${PROXMOX_TOKEN}"
provisioning_root_password: "${PROV_PASS}"
searxng_root_password: "${SEARXNG_PASS}"
openclaw_root_password: "${OPENCLAW_PASS}"
searxng_secret_key: "${SEARXNG_KEY}"
provisioning_deploy_key: |
${DEPLOY_KEY}
VAULTEOF

ansible-vault encrypt /tmp/vault_plain.yml \
  --vault-password-file "$VAULT_PASS_FILE" \
  --output "$VAULT_FILE"
rm -f /tmp/vault_plain.yml

echo ""
echo "All passwords rotated and vault updated."
echo "New passwords stored in vault only — not displayed."
echo "Run: make configure to sync any password-dependent config"