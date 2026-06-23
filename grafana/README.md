# Grafana Dashboards

Source-of-truth backups of the hand-built Grafana dashboards on Hawkeye.

## hawkeye-dashboard.json

The "Hawkeye" dashboard - Spectrum outage + Proxmox + NAS observability.
Exported in Grafana's v2 schema (`dashboard.grafana.app/v2`). We keep the v2
export (not the classic/legacy format) because classic export drops newer panel
features this dashboard uses.

### Why this is in the repo (not a NAS sync)

A dashboard definition is small, textual, and changes infrequently - ideal for
git: full history, diffs, rollback, and it lives alongside the IaC (exporters,
scrape jobs, alert rules) that produces the metrics it displays. A cron-to-NAS
sync would give a single historyless blob and another silent-failure moving
part. (NAS sync is right for large binary runtime state like OpenClaw's; wrong
for a config file like this.)

### Restore after a rebuild

Auto-provisioning is intentionally NOT wired yet: Grafana's file-based
provisioner does not reliably consume the v2 schema. Restore is a manual import,
which accepts the v2 export cleanly:

1. Grafana (https://hawkeye.snorp.dev) > Dashboards > New > Import.
2. Upload `hawkeye-dashboard.json` (or paste its contents).
3. Map the Prometheus datasource if prompted, and Import.

### Updating the backup

After changing the dashboard in the UI:

1. Dashboard > Export > Save to file (v2 export).
2. Replace `hawkeye-dashboard.json` with the new export.
3. Commit. The git diff is your change record.

### Future: auto-provisioning

When Grafana's file provisioner supports the v2 schema (or if a classic export
becomes acceptable), wire a dashboard provider into the hawkeye role pointing at
this file so restore becomes automatic on apply. Tracked as a follow-up.
