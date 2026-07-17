#!/usr/bin/env bash
set -euo pipefail

echo "Validating rendered stack templates with ansible syntax and YAML parsing"
ansible-playbook --syntax-check ansible/rpi-ha.yaml

python3 <<'PY'
from pathlib import Path

import yaml
from jinja2 import Environment, FileSystemLoader

env = Environment(loader=FileSystemLoader("stacks"))

render_plan = [
	(
		"network.stack.yml.j2",
		{
			"twingate": {
				"network": "bancetech",
				"thanos": {
					"refresh_token": "mock-refresh-token",
					"access_token": "mock-access-token",
				},
			},
			"rpi_network_adguard_replicas": 1,
			"rpi_network_bunkerweb_replicas": 1,
		},
	),
	(
		"monitoring.stack.yml.j2",
		{
			"adguard_username": "mock-user",
			"adguard_password": "mock-password",
			"rpi_monitoring_adguard_exporter_replicas": 1,
			"rpi_monitoring_gatus_replicas": 1,
		},
	),
]

for template_name, context in render_plan:
	rendered = env.get_template(template_name).render(**context)
	yaml.safe_load(rendered)
	Path("/tmp").joinpath(template_name.replace(".j2", "")).write_text(rendered)
	print(f"Rendered and parsed {template_name}")
PY

echo "Validation passed"
