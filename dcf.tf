locals {
  add_icmp_deny = contains(["deny_icmp"], var.dcf_scenario)
  add_all_deny  = var.dcf_scenario == "deny_all"
}

# Tag-based Smart Groups — matches VMs by Azure tag set in vms.tf
resource "aviatrix_smart_group" "spoke1_vms" {
  name = "sg-spoke1-vms"
  selector {
    match_expressions {
      type         = "vm"
      account_name = var.aviatrix_azure_account_name
      region       = "France Central"
      tags         = { application = "app1" }
    }
  }
}

resource "aviatrix_smart_group" "spoke2_vms" {
  name = "sg-spoke2-vms"
  selector {
    match_expressions {
      type         = "vm"
      account_name = var.aviatrix_azure_account_name
      region       = "France Central"
      tags         = { application = "app2" }
    }
  }
}

resource "aviatrix_distributed_firewalling_policy_list" "demo" {

  # Scenario: deny_icmp — blocks ping, allows everything else
  dynamic "policies" {
    for_each = local.add_icmp_deny ? [1] : []
    content {
      name             = "deny-icmp-spoke1-to-spoke2"
      action           = "DENY"
      priority         = 10
      src_smart_groups = [aviatrix_smart_group.spoke1_vms.uuid]
      dst_smart_groups = [aviatrix_smart_group.spoke2_vms.uuid]
      protocol         = "ICMP"
      logging          = true
    }
  }

  dynamic "policies" {
    for_each = local.add_icmp_deny ? [1] : []
    content {
      name             = "deny-icmp-spoke2-to-spoke1"
      action           = "DENY"
      priority         = 11
      src_smart_groups = [aviatrix_smart_group.spoke2_vms.uuid]
      dst_smart_groups = [aviatrix_smart_group.spoke1_vms.uuid]
      protocol         = "ICMP"
      logging          = true
    }
  }

  # Scenario: deny_all — blocks all spoke1 ↔ spoke2 traffic
  dynamic "policies" {
    for_each = local.add_all_deny ? [1] : []
    content {
      name             = "deny-all-spoke1-to-spoke2"
      action           = "DENY"
      priority         = 10
      src_smart_groups = [aviatrix_smart_group.spoke1_vms.uuid]
      dst_smart_groups = [aviatrix_smart_group.spoke2_vms.uuid]
      protocol         = "Any"
      logging          = true
    }
  }

  dynamic "policies" {
    for_each = local.add_all_deny ? [1] : []
    content {
      name             = "deny-all-spoke2-to-spoke1"
      action           = "DENY"
      priority         = 11
      src_smart_groups = [aviatrix_smart_group.spoke2_vms.uuid]
      dst_smart_groups = [aviatrix_smart_group.spoke1_vms.uuid]
      protocol         = "Any"
      logging          = true
    }
  }

  # Watch: egress to Public Internet and AllWeb webgroup — logging only, no block
  policies {
    name             = "watch-spoke1-to-internet"
    action           = "PERMIT"
    priority         = 50
    src_smart_groups = [aviatrix_smart_group.spoke1_vms.uuid]
    dst_smart_groups = ["def000ad-0000-0000-0000-000000000001"]
    web_groups       = ["def000ad-0000-0000-0000-000000000002"]
    protocol         = "Any"
    logging          = true
  }

  policies {
    name             = "watch-spoke2-to-internet"
    action           = "PERMIT"
    priority         = 51
    src_smart_groups = [aviatrix_smart_group.spoke2_vms.uuid]
    dst_smart_groups = ["def000ad-0000-0000-0000-000000000001"]
    web_groups       = ["def000ad-0000-0000-0000-000000000002"]
    protocol         = "Any"
    logging          = true
  }

  # Baseline: always-on permit for spoke1 ↔ spoke2
  policies {
    name             = "allow-spoke1-to-spoke2"
    action           = "PERMIT"
    priority         = 100
    src_smart_groups = [aviatrix_smart_group.spoke1_vms.uuid]
    dst_smart_groups = [aviatrix_smart_group.spoke2_vms.uuid]
    protocol         = "Any"
    logging          = true
  }

  policies {
    name             = "allow-spoke2-to-spoke1"
    action           = "PERMIT"
    priority         = 101
    src_smart_groups = [aviatrix_smart_group.spoke2_vms.uuid]
    dst_smart_groups = [aviatrix_smart_group.spoke1_vms.uuid]
    protocol         = "Any"
    logging          = true
  }
}
