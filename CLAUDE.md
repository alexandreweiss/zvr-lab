# ZVR Lab — Claude Context

## What this deploys

Azure hub-and-spoke built for ZVR customer engagement. Aviatrix spoke gateway in hub acts as virtual router.
No Aviatrix transit gateway. East-west spoke traffic is steered via UDRs → ILB → Aviatrix GW.

## File map

| File | Purpose |
|---|---|
| `main.tf` | Azure infra: VNets, subnets, ILB, route tables, VNet peerings |
| `aviatrix.tf` | Aviatrix mc-spoke module + VPN gateway + VPN user |
| `vms.tf` | Ubuntu 22.04 VMs in spoke1 and spoke2 |
| `variables.tf` | Inputs: controller IP/creds, Azure account name |
| `outputs.tf` | VNet IDs and address spaces |
| `versions.tf` | Provider constraints, Terraform Cloud backend |

## Key design decisions

**ILB + UDR as traffic steering** — Spoke route tables send 0.0.0.0/0 to the ILB frontend IP. ILB is HA-ports SKU, distributes to active/standby Aviatrix gateway NICs. Hub shared subnet has a `0.0.0.0/0 → None` blackhole to prevent hub-native internet breakout.

**`single_ip_snat = true` is optional for symmetry** — Azure ILB 5-tuple hash guarantees both directions of a flow hit the same gateway. SNAT is not required to fix asymmetric routing in this topology.

**`attached = false`** — Gateway is standalone. It advertises spoke CIDRs (`10.1.0.0/16, 10.2.0.0/16`) via `included_advertised_spoke_routes` for future transit attachment.

**`use_existing_vpc = true`** — Gateway deploys into the pre-created hub VNet. VPC ID format: `<vnet-name>:<rg-name>:<vnet-guid>`.

**VPN gateway is a separate `aviatrix_gateway` resource** (not mc-spoke) because it needs `vpn_access = true` and split tunnel config.

## Provider constraints

- `azurerm ~>3.0`
- `tls ~>4.0` — generates RSA-4096 SSH key pair; private key written to `ssh_key.pem` (gitignored)
- `local ~>2.0` — writes `ssh_key.pem` with `0600` permissions
- `aviatrix ~>9.0` — targets controller 9.0. mc-spoke module must be ≥9.0.0 (`requires aviatrix >=9.0.0`)
- Backend: **local** — `terraform.tfstate` in working directory

## Azure dependencies (must exist before apply)

- Aviatrix Azure account onboarded in controller — account name passed via `var.aviatrix_azure_account_name`
- No dependency on any pre-existing resource group or SSH key

## Shared controller constraints

DCF must be enabled manually on the controller before applying `dcf.tf` — this is a shared controller (9.0), Terraform must NOT touch global feature flags. `aviatrix_config_feature` and `aviatrix_distributed_firewalling_config` are both excluded intentionally.

Policy pruning is disabled per gateway via API (not Terraform):
```bash
CID=$(curl -sk -X POST "https://<controller>/v1/api" \
  -d "action=login&username=admin&password=<pwd>" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['CID'])")
curl -k -X PUT "https://<controller>/v2.5/api/microseg/gateway/avx-spoke-hub-frc" \
  -H "Authorization: cid $CID" -H "Content-Type: application/json"
```

## Common issues

**NIC data source fails** — `avx_gw_nic` name is `av-nic-<gw_name>`. If gateway name changes, this auto-updates. Data source has `depends_on = [module.mc_spoke_hub]`.

**ILB frontend IP is dynamic** — After first apply, route tables reference `azurerm_lb.hub_internal.frontend_ip_configuration[0].private_ip_address`. This creates an implicit dependency; Terraform plans correctly, but state refresh order matters on partial applies.

**Destroy hangs on LB association** — Azure releases NICs asynchronously. Re-run `terraform destroy` if it times out.

**DCF policy pruning** — Smart Groups that resolve to the same Aviatrix tag (same spoke VNet) get pruned. Use CIDR-based Smart Groups for east-west rules.

## VPN user

`zvr-user` (aweiss@aviatrix.com) — download `.ovpn` from Controller → VPN → VPN Users.
Split tunnel: only `10.1.0.0/16` and `10.2.0.0/16` route through VPN. VPN pool: `192.168.43.0/24`.
