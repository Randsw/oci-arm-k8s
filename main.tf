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
    security_list_ids = "${split(",", oci_core_security_list.k8s_security_list.id)}"
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
        protocol = "6"
        source   = "0.0.0.0/0"
        description = "Allow http connection"
        tcp_options {
            min = "80"
            max = "80"
        }
     }

        ingress_security_rules {
        protocol = "6"
        source   = "0.0.0.0/0"
        description = "Allow https connection"
            tcp_options {
                min = "443"
                max = "443"
            }
        }

    ingress_security_rules {
        protocol = "6"
        source   = data.oci_core_subnets.public_subnets.subnets[0].cidr_block
        description = "Allow connection to k8s api from public subnet through OpenVPN"
        tcp_options {
            min = "6443"
            max = "6443"
        }
     }

    ingress_security_rules {
        protocol = "6"
        source   = var.private_subnet_cidr_block
        description = "Allow connection k8s CNI BGP connection in private subnet"
        tcp_options {
            min = "179"
            max = "179"
        }
     }

    ingress_security_rules {
        protocol = "17"
        source   = "0.0.0.0/0"
        description = "Allow ntp connection"
        tcp_options {
            min = "123"
            max = "123"
        }
     }

    ingress_security_rules {
        protocol = "4"
        source   = data.oci_core_subnets.public_subnets.subnets[0].cidr_block
        description = "Allow IPIP connection from public subnet"
     }

    ingress_security_rules {
        protocol = "4"
        source   = var.private_subnet_cidr_block
        description = "Allow IPIP connection"
     }

    ingress_security_rules {
        protocol = "6"
        source   = data.oci_core_subnets.public_subnets.subnets[0].cidr_block
        description = "Allow ssh connection from public subnet"
        tcp_options {
            min = "22"
            max = "22"
        }
     }

    ingress_security_rules {
        protocol = "17"
        source   = data.oci_core_subnets.public_subnets.subnets[0].cidr_block
        description = "Allow vpn connection from public subnet"
        tcp_options {
            min = "1194"
            max = "1194"
        }
     }
     egress_security_rules {
        protocol = "6"
        destination   = "0.0.0.0/0"
     }

    egress_security_rules {
        protocol = "17"
        destination   = "0.0.0.0/0"
        description = "OpenVPN egress"
        udp_options {
            min = "1194"
            max = "1194"
        }
     }
    egress_security_rules {
        protocol = "17"
        destination   = "0.0.0.0/0"
        description = "NTP egress"
        udp_options {
            min = "123"
            max = "123"
        }
     }
    egress_security_rules {
        protocol = "4"
        destination   = var.private_subnet_cidr_block
        description = "IPIP private subnet egress block"
     }
}

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