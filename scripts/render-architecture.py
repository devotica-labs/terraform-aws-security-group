#!/usr/bin/env python3
"""Render an AWS architecture diagram from a Terraform plan JSON.

Reads the output of `terraform show -json plan.binary` from the
`examples/complete/` plan, draws the security group as a central node, and
draws each ingress/egress rule as its own node with a label summarising
protocol, port range, and target (CIDR / referenced SG / prefix list),
connected with directional edges into or out of the security group.

Rule attributes (protocol, ports, cidr_ipv4, etc.) are direct user inputs
passed through from each.value.*, not AWS-computed values, so they are
known at plan time even before the security group exists — the same reason
the S3 and VPC render scripts can show CIDR blocks pre-apply.

This script is invoked from `.github/workflows/architecture-diagram.yml`
on every PR and on push to main. The committed PNG lives at
`docs/architecture.png` and is embedded in README.md between
`<!-- BEGIN_ARCH -->` / `<!-- END_ARCH -->` markers.

Usage:
    python scripts/render-architecture.py <plan.json> <output-path-no-ext>

Example:
    python scripts/render-architecture.py examples/complete/plan.json docs/architecture
        -> writes docs/architecture.png
"""

from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.general import General


def load_resources(plan_path: Path) -> list[dict]:
    """Flatten every resource (root + child modules) from a Terraform plan JSON."""
    plan = json.loads(plan_path.read_text())
    root = plan.get("planned_values", {}).get("root_module", {})
    collected: list[dict] = []

    def walk(mod: dict) -> None:
        for r in mod.get("resources", []):
            collected.append(r)
        for child in mod.get("child_modules", []):
            walk(child)

    walk(root)
    return collected


def values(r: dict) -> dict:
    return r.get("values", {}) or {}


def rule_key(address: str) -> str:
    """Extract a short, human-friendly key from a resource address.

    Handles both for_each addressing (`...this["my-rule"]` -> "my-rule")
    and count addressing (`...allow_all[0]` -> "allow_all").
    """
    m = re.search(r'\["([^"]+)"\]$', address)
    if m:
        return m.group(1)
    m = re.search(r"\.([a-zA-Z0-9_]+)\[\d+\]$", address)
    if m:
        return m.group(1)
    m = re.search(r"\.([a-zA-Z0-9_]+)$", address)
    if m:
        return m.group(1)
    return address


def rule_label(v: dict) -> str:
    """Build a short multi-line label: protocol:ports, target, (description)."""
    proto = v.get("ip_protocol", "?")
    proto_label = "all" if proto == "-1" else str(proto)

    from_p = v.get("from_port")
    to_p = v.get("to_port")
    if from_p is not None and to_p is not None:
        port_label = str(from_p) if from_p == to_p else f"{from_p}-{to_p}"
    else:
        port_label = "?"

    target = (
        v.get("cidr_ipv4")
        or v.get("cidr_ipv6")
        or v.get("referenced_security_group_id")
        or v.get("prefix_list_id")
        or "?"
    )

    label = f"{proto_label}:{port_label}\n{target}"
    desc = v.get("description")
    if desc:
        label += f"\n({desc})"
    return label


def render(plan_path: Path, out_no_ext: Path) -> None:
    resources = load_resources(plan_path)
    by_type: dict[str, list[dict]] = defaultdict(list)
    for r in resources:
        by_type[r["type"]].append(r)

    sgs = by_type.get("aws_security_group", [])
    if not sgs:
        raise SystemExit("No aws_security_group resource found in plan — nothing to render.")

    sg_name = values(sgs[0]).get("name") or "security-group"
    ingress_rules = by_type.get("aws_vpc_security_group_ingress_rule", [])
    egress_rules = by_type.get("aws_vpc_security_group_egress_rule", [])

    graph_attr = {
        "fontsize": "20",
        "splines": "ortho",
        "ranksep": "0.9",
        "nodesep": "0.4",
        "pad": "0.5",
    }

    out_no_ext.parent.mkdir(parents=True, exist_ok=True)

    with Diagram(
        f"terraform-aws-security-group — {sg_name}",
        filename=str(out_no_ext),
        show=False,
        direction="LR",
        outformat="png",
        graph_attr=graph_attr,
    ):
        sg_node = General(f"Security Group\n{sg_name}")

        if ingress_rules:
            with Cluster("Ingress (inbound)"):
                for r in ingress_rules:
                    key = rule_key(r["address"])
                    node = General(rule_label(values(r)))
                    node >> Edge(label=key) >> sg_node

        if egress_rules:
            with Cluster("Egress (outbound)"):
                for r in egress_rules:
                    key = rule_key(r["address"])
                    node = General(rule_label(values(r)))
                    sg_node >> Edge(label=key) >> node


def main() -> None:
    if len(sys.argv) < 3:
        sys.stderr.write(
            "Usage: render-architecture.py <plan.json> <output-path-without-ext>\n"
        )
        sys.exit(2)
    render(Path(sys.argv[1]), Path(sys.argv[2]))


if __name__ == "__main__":
    main()
