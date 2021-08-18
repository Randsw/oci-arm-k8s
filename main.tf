terraform {
   backend "s3" {
    endpoint                    = "https://frd8bsyrgar7.compat.objectstorage.eu-frankfurt-1.oraclecloud.com"
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
    skip_credentials_validation = true
    bucket                      = "tf-state"
    key                         = "arm-k8s/terraform.tfstate"
    region                      = "eu-frankfurt-1"
  }
  required_providers {
    oci = {
        source  = "hashicorp/oci"
        version = ">= 4.0.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "~> 0.5"
    }
  }
}

locals {
    security_list_ids = "${split(",", module.oci-security.security_list_id)}"
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = data.oci_identity_compartments.vpn_compartments.compartments[0].id
}

data "oci_identity_compartments" "vpn_compartments" {
    compartment_id = data.sops_file.secret.data["tenancy"]
    access_level = "ACCESSIBLE"
    name = var.compartment_name
    state = var.compartment_state
}

data "oci_core_vcns" "existing_vcns" {
    compartment_id   = data.oci_identity_compartments.vpn_compartments.compartments[0].id
    display_name     = var.vcn_display_name
    state            = var.vcn_state
}

data "oci_core_instances" "existing_instance" {
    compartment_id   = data.oci_identity_compartments.vpn_compartments.compartments[0].id
    display_name     = var.vpn_instance_name
}

data "oci_core_subnets" "public_subnets" {
    compartment_id = data.oci_identity_compartments.vpn_compartments.compartments[0].id
    display_name = var.subnet_display_name
    vcn_id = data.oci_core_vcns.existing_vcns.virtual_networks[0].id
}

data "oci_core_private_ips" "private_ips_by_subnet" {
    subnet_id = data.oci_core_subnets.public_subnets.subnets[0].id
}

data "oci_core_security_lists" "vpn_security_lists" {
    compartment_id = data.oci_identity_compartments.vpn_compartments.compartments[0].id
    display_name = var.vpn_security_list_display_name
    vcn_id = data.oci_core_vcns.existing_vcns.virtual_networks[0].id
}

module "oci-security" {
    source = "git@github.com:Randsw/oci-terraform-security.git"

    vcn_id             = data.oci_core_vcns.existing_vcns.virtual_networks[0].id
    compartment_id     = data.oci_identity_compartments.vpn_compartments.compartments[0].id
    app_tags           = var.app_tags
    security_list_name = var.security_list_name
    egress_rule        = var.egress_rule
    tcp_ingress_rule   = var.tcp_ingress_rule
    udp_ingress_rule   = var.udp_ingress_rule
}

resource "oci_core_route_table" "private_subnet_route_table" {
    compartment_id = data.oci_identity_compartments.vpn_compartments.compartments[0].id
    vcn_id = data.oci_core_vcns.existing_vcns.virtual_networks[0].id
    display_name = var.private_subnet_route_table_display_name
    freeform_tags = var.app_tags
    route_rules {
        network_entity_id = data.oci_core_private_ips.private_ips_by_subnet.private_ips[0].id
        description = "Route to vpn server"
        destination = "0.0.0.0/0"
        destination_type = "CIDR_BLOCK"
    }
}

resource "oci_core_subnet" "private_subnet" {
    cidr_block = var.private_subnet_cidr_block
    compartment_id = data.oci_identity_compartments.vpn_compartments.compartments[0].id
    vcn_id = data.oci_core_vcns.existing_vcns.virtual_networks[0].id


    display_name = var.private_subnet_display_name
    freeform_tags = var.app_tags

    route_table_id = oci_core_route_table.private_subnet_route_table.id
    security_list_ids = local.security_list_ids
}

resource "oci_core_security_list" "k8s_security_list" {
    compartment_id = data.oci_identity_compartments.vpn_compartments.compartments[0].id
    vcn_id = data.oci_core_vcns.existing_vcns.virtual_networks[0].id
    display_name = var.k8s_security_list_name
    freeform_tags = var.app_tags

     ingress_security_rules {
        protocol = "all"
        source   = var.private_subnet_cidr_block
     }
     egress_security_rules {
        protocol = "all"
        destination   = "0.0.0.0/0"
     }
}

#Patch existing subnet security list. Need to add this security list to exist private subnet. But we cant do this in terraform, 
#so we need to create it manualy in web gui.

resource "oci_core_instance" "k8s-cp-instance" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[2].name
  compartment_id      = data.oci_identity_compartments.vpn_compartments.compartments[0].id
  display_name        = "k8s-cp"
  shape               = "VM.Standard.A1.Flex"
  freeform_tags       = var.app_tags

  create_vnic_details {
    subnet_id               = oci_core_subnet.private_subnet.id
    display_name            = "k8s-cp VNIC"
    assign_public_ip        = false
    hostname_label          = "k8s-cp"
    private_ip              = var.k8s_cp_private_ip
    skip_source_dest_check  = true
  }

  shape_config {
        memory_in_gbs = 12
        ocpus = 2
    }

  source_details {
    source_type = "image"
    source_id   = "${var.image_id[var.region]}"
  }

  metadata = {
    ssh_authorized_keys = "${file(var.ssh_key_public)}"
  }
}

resource "oci_core_instance" "k8s-worker-instance" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[2].name
  compartment_id      = data.oci_identity_compartments.vpn_compartments.compartments[0].id
  display_name        = "k8s-worker"
  shape               = "VM.Standard.A1.Flex"
  freeform_tags       = var.app_tags

  create_vnic_details {
    subnet_id               = oci_core_subnet.private_subnet.id
    display_name            = "k8s-worker VNIC"
    assign_public_ip        = false
    hostname_label          = "k8s-worker"
    private_ip              = var.k8s_worker_private_ip
    skip_source_dest_check  = true
  }

  shape_config {
        memory_in_gbs = 12
        ocpus = 2
    }

  source_details {
    source_type = "image"
    source_id   = "${var.image_id[var.region]}"
  }

  metadata = {
    ssh_authorized_keys = "${file(var.ssh_key_public)}"
  }
}