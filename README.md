# ZVR Lab

Hub-and-spoke Azure lab built for the ZVR customer engagement. An Aviatrix spoke gateway deployed inside the hub VNet acts as a centralized virtual router, intercepting all east-west spoke traffic for inspection and DCF policy enforcement — without a traditional transit gateway or NVA.

---

## Architecture

```
  VPN Users (192.168.43.0/24)
       │ split tunnel: 10.1/16, 10.2/16
  [avx-vpn-hub-frc]  10.0.5.0/24
       │
  ┌────┴──────────────────────────────────────────┐
  │               Hub VNet  10.0.0.0/16           │
  │                                               │
  │  subnet-shared  10.0.2.0/24                   │
  │  ┌─────────────────────────────────────────┐  │
  │  │  Internal Load Balancer (HA Ports SKU)  │  │
  │  │         frontend IP (dynamic)           │  │
  │  └──────────────┬──────────────────────────┘  │
  │           ┌─────┴──────┐                      │
  │     NIC assoc.     NIC assoc.                 │
  │           │             │                     │
  │  [avx-spoke-hub-frc]  [avx-spoke-hub-frc-hagw]│
  │   active GW             standby GW            │
  │   10.0.3.0/24           10.0.4.0/24           │
  │                                               │
  └────┬────────────────────────────┬─────────────┘
       │  VNet Peering              │  VNet Peering
       │  (allow_gateway_transit)   │  (allow_gateway_transit)
  ┌────┴────────────┐     ┌─────────┴──────────┐
  │  Spoke 1 VNet   │     │   Spoke 2 VNet      │
  │  10.1.0.0/16    │     │   10.2.0.0/16       │
  │                 │     │                     │
  │  subnet-workload│     │   subnet-workload   │
  │  10.1.1.0/24    │     │   10.2.1.0/24       │
  │  UDR:0.0.0.0/0  │     │   UDR:0.0.0.0/0     │
  │  → ILB frontend │     │   → ILB frontend    │
  │                 │     │                     │
  │  vm-spoke1-linux│     │   vm-spoke2-linux   │
  │  (Ubuntu 22.04) │     │   (Ubuntu 22.04)    │
  └─────────────────┘     └─────────────────────┘

  East-west path: vm-spoke1 ──UDR──► ILB ──► Aviatrix GW ──► vm-spoke2
  Return path:    vm-spoke2 ──UDR──► ILB ──► Aviatrix GW ──► vm-spoke1
```

**East-west flow (Spoke 1 → Spoke 2):**

1. `vm-spoke1` sends to `10.2.1.x` → UDR on `subnet-workload` sends to ILB frontend IP
2. ILB forwards to active Aviatrix gateway (5-tuple hash — same GW for both directions)
3. Gateway applies DCF policy and forwards to `10.2.1.x`
4. Return path: `vm-spoke2` → UDR → ILB → same Aviatrix GW → `vm-spoke1`

Symmetric routing is guaranteed by the ILB 5-tuple hash — both directions of a flow land on the same gateway. SNAT is not required.

### Network layout

| Resource | Name | CIDR |
|---|---|---|
| Hub VNet | vnet-hub-frc | 10.0.0.0/16 |
| Hub: GatewaySubnet | — | 10.0.1.0/24 |
| Hub: shared (ILB frontend) | subnet-shared | 10.0.2.0/24 |
| Hub: Aviatrix GW | avx-gw | 10.0.3.0/24 |
| Hub: Aviatrix HA GW | avx-ha-gw | 10.0.4.0/24 |
| Hub: VPN GW | avx-vpn-gw | 10.0.5.0/24 |
| Spoke 1 VNet | vnet-spoke1-frc | 10.1.0.0/16 |
| Spoke 1: workload | subnet-workload | 10.1.1.0/24 |
| Spoke 2 VNet | vnet-spoke2-frc | 10.2.0.0/16 |
| Spoke 2: workload | subnet-workload | 10.2.1.0/24 |
| VPN pool | — | 192.168.43.0/24 |

---

## Prerequisites

### 1. Azure

- Subscription with Contributor or Owner
- Azure CLI authenticated (`az login`) or service principal configured

### 2. Aviatrix Controller

- Controller FQDN/IP reachable from where Terraform runs
- Azure account already onboarded in the controller
- Admin credentials available

### 3. Terraform

- Terraform ≥ 1.5
- State is **local** — `terraform.tfstate` is written to the working directory. Back it up if needed.

### 4. Lab access

- [Aviatrix VPN Client](https://docs.aviatrix.com/documentation/latest/official-release/release-notes.html) installed — needed to reach VMs (no public IPs)

---

## Deploy

### 1. Configure variables

```bash
cp terraform.tfvars.sample terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aviatrix_controller_ip      = "controller-prd.ananableu.fr"
aviatrix_username           = "admin"
aviatrix_password           = "..."
aviatrix_azure_account_name = "azure-alweiss"
```

> **Terraform Cloud:** set these as workspace variables instead. Mark `aviatrix_password` as sensitive.

### 2. Apply

```bash
terraform init
terraform plan
terraform apply
```

Apply takes **15–20 minutes**; Aviatrix gateway provisioning dominates.

---

## Test: spoke-to-spoke traffic

### Step 1 — Get VM IPs

```bash
terraform output spoke1_vm_private_ip
terraform output spoke2_vm_private_ip
```

Or: Azure Portal → Resource group `zvr-frc-zvr` → NICs `nic-vm-spoke1` / `nic-vm-spoke2`.

### Step 2 — Connect to VPN

1. Aviatrix Controller → **VPN → VPN Users** → `zvr-user` → **Download config**
2. Import the `.ovpn` profile into Aviatrix VPN Client and connect
3. Your assigned IP will be in `192.168.43.0/24`

### Step 3 — SSH to Spoke 1 VM

```bash
ssh -i $(terraform output -raw ssh_private_key_path) admin-lab@<spoke1_vm_private_ip>
```

### Step 4 — Test connectivity to Spoke 2

From `vm-spoke1`:

```bash
# ICMP
ping <spoke2_vm_private_ip>

# TCP port check
nc -zv <spoke2_vm_private_ip> 22

# Bidirectional data transfer (open a second SSH session to vm-spoke2)
# On vm-spoke2:  nc -lvp 9000
# On vm-spoke1:  echo "hello from spoke1" | nc <spoke2_vm_private_ip> 9000
```

### Expected results

| Test | Result |
|---|---|
| Spoke 1 → Spoke 2 ping | Success — traffic routes through Aviatrix GW |
| Spoke 2 → Spoke 1 ping | Success |
| Direct spoke1↔spoke2 without UDR | Fail — no peering between spokes |

### Verify traffic passes through gateway

Aviatrix Controller → **Monitor → Gateway** → select `avx-spoke-hub-frc` → check active session table or byte counters during test.

---

## Test: DCF policy enforcement

Smart Groups `sg-spoke1-vms` and `sg-spoke2-vms` are tag-based (`application=app1` / `application=app2`). Toggle `dcf_scenario` in `terraform.tfvars` and re-apply to switch enforcement mode — no code changes needed.

Each VM runs a **Gatus** monitoring dashboard (installed via cloud-init at boot) that continuously probes the other spoke for ICMP, TCP 22, and TCP 9000. Open both dashboards before running the demo — status flips within 5 seconds of a policy push.

```bash
terraform output gatus_spoke1_dashboard   # http://<spoke1-ip>:8080 — monitors spoke2
terraform output gatus_spoke2_dashboard   # http://<spoke2-ip>:8080 — monitors spoke1
```

> Dashboards require VPN. Allow ~2 minutes after first boot for Docker + Gatus to start.

| `dcf_scenario` | Effect |
|---|---|
| `allow_all` (default) | Baseline permit — all spoke1 ↔ spoke2 traffic flows |
| `deny_icmp` | ICMP blocked, TCP/UDP still flows (ping fails, SSH works) |
| `deny_all` | All spoke1 ↔ spoke2 traffic blocked |

### Demo sequence

**Step 1 — Baseline (allow_all)**

```bash
# terraform.tfvars: dcf_scenario = "allow_all"
terraform apply

# From vm-spoke1:
ping <spoke2_vm_private_ip>          # success
nc -zv <spoke2_vm_private_ip> 22     # success
```

**Step 2 — Selective enforcement (deny_icmp)**

```bash
# terraform.tfvars: dcf_scenario = "deny_icmp"
terraform apply   # ~seconds, policy push only

# From vm-spoke1:
ping <spoke2_vm_private_ip>          # fails — ICMP blocked
nc -zv <spoke2_vm_private_ip> 22     # success — TCP still allowed
```

**Step 3 — Full block (deny_all)**

```bash
# terraform.tfvars: dcf_scenario = "deny_all"
terraform apply

# From vm-spoke1:
ping <spoke2_vm_private_ip>          # fails
nc -zv <spoke2_vm_private_ip> 22     # fails
```

**Step 4 — Restore**

```bash
# terraform.tfvars: dcf_scenario = "allow_all"
terraform apply
```

### Observe in CoPilot

CoPilot → **Security → Distributed Cloud Firewall** → Policy Logs — shows hits with action PERMIT/DENY per rule, with source/destination Smart Group names.

---

## Known behaviors

**`attached = false`** — The spoke gateway is standalone, not connected to a transit. This is intentional: the lab uses the gateway as a pure virtual router. Attach to a transit gateway to extend to multi-cloud.

**DCF policy pruning** — If source and destination Smart Groups both resolve to the same gateway (both spokes share one GW in this topology), Aviatrix prunes the policy as a no-op. Policies appear in the controller but are silently dropped before being pushed to the gateway.

To disable pruning, set this env var on the controller before applying DCF rules:

```
Container: avx-ctrl-state-sync
Env var:   AVX_CTRL_MICROSEG_DISABLE_POLICY_PRUNING=true
```

**Symmetric routing** — Azure ILB uses a 5-tuple hash (src IP, dst IP, src port, dst port, protocol), so both directions of a flow always land on the same Aviatrix gateway. SNAT is not needed for spoke-to-spoke symmetry in this topology.

---

## Cleanup

```bash
terraform destroy
```

If destroy fails on NIC/LB association resources, Azure is still releasing the ILB. Re-run `terraform destroy`.
