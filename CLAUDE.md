# ZVR Lab — Claude Context

## What this deploys

Azure hub-and-spoke with an Aviatrix spoke gateway in the hub acting as a virtual router (ZVR pattern).
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

**`single_ip_snat = true` is required** — Disabling it breaks return traffic on spoke-to-spoke flows. SNAT makes return traffic symmetric through the gateway.

**`attached = false`** — Gateway is standalone. It advertises spoke CIDRs (`10.1.0.0/16, 10.2.0.0/16`) via `included_advertised_spoke_routes` for future transit attachment.

**`use_existing_vpc = true`** — Gateway deploys into the pre-created hub VNet. VPC ID format: `<vnet-name>:<rg-name>:<vnet-guid>`.

**VPN gateway is a separate `aviatrix_gateway` resource** (not mc-spoke) because it needs `vpn_access = true` and split tunnel config.

## Provider constraints

- `azurerm ~>3.0` (not 4.x — data source `azurerm_ssh_public_key` syntax differs)
- `aviatrix` — version pinned by Terraform Cloud. Controller is 8.2, use mc-spoke ≤8.2.x
- Backend: Terraform Cloud org `ananableu`, workspace `zvr-lab`

## Azure dependencies (must exist before apply)

- SSH public key `ssh-linux-non-prod` in resource group `core-rg` — both VMs use it
- Aviatrix Azure account `azure-alweiss` onboarded in controller (subscription `cc67e95e`)

## Common issues

**NIC data source fails** — `avx_gw_nic` name is `av-nic-<gw_name>`. If gateway name changes, this auto-updates. Data source has `depends_on = [module.mc_spoke_hub]`.

**ILB frontend IP is dynamic** — After first apply, route tables reference `azurerm_lb.hub_internal.frontend_ip_configuration[0].private_ip_address`. This creates an implicit dependency; Terraform plans correctly, but state refresh order matters on partial applies.

**Destroy hangs on LB association** — Azure releases NICs asynchronously. Re-run `terraform destroy` if it times out.

**DCF policy pruning** — Smart Groups that resolve to the same Aviatrix tag (same spoke VNet) get pruned. Use CIDR-based Smart Groups for east-west rules.

## VPN user

`zvr-user` (aweiss@aviatrix.com) — download `.ovpn` from Controller → VPN → VPN Users.
Split tunnel: only `10.1.0.0/16` and `10.2.0.0/16` route through VPN. VPN pool: `192.168.43.0/24`.
