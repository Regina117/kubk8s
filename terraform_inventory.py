#!/usr/bin/env python3
import json
import subprocess

def get_terraform_outputs():
    try:
        result = subprocess.run(
            ["terraform", "output", "-json"],
            capture_output=True,
            text=True,
            check=True
        )
        return json.loads(result.stdout)
    except Exception as e:
        print(f"Error: {e}")
        exit(1)

def generate_inventory(outputs):
    inventory = {
        "_meta": {
            "hostvars": {}
        },
        "all": {
            "children": ["master", "workers"]
        },
        "master": {
            "hosts": []
        },
        "workers": {
            "hosts": []
        }
    }

    if "nodes_external_ips" in outputs:
        for name, ip in outputs["nodes_external_ips"]["value"].items():
            if "master" in name:
                inventory["master"]["hosts"].append(ip)
            else:
                inventory["workers"]["hosts"].append(ip)

            inventory["_meta"]["hostvars"][ip] = {
                "ansible_user": "regina",
                "ansible_ssh_private_key_file": "/home/regina/.ssh/id_rsa",
                "ansible_ssh_common_args": "-o StrictHostKeyChecking=no"
            }

    return inventory

if __name__ == "__main__":
    terraform_outputs = get_terraform_outputs()
    inventory = generate_inventory(terraform_outputs)
    print(json.dumps(inventory, indent=2))
