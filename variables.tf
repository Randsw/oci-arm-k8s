variable "ssh_key_public" {
  default     = "~/ya_rsa.pub"
  description = "Path to the SSH public key for accessing cloud instances. Used for creating AWS keypair."
}

variable "ssh_key_private" {
  default     = "~/ya_rsa"
  description = "Path to the SSH public key for accessing cloud instances. Used for creating AWS keypair."
}

variable "region" {
  default = "eu-frankfurt-1" 
  description = "Tenancy region"
}

variable "image_id" {
  type = map(string)
  default = {
    eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaa4e2ghww37p3owr7pxtz6uirsdljbegjaejgm7vmnjqyumvqg2evq"
  }
}

variable "compartment_name" {
    type = string
}

variable "compartment_state" {
    type = string  
    default = "ACTIVE"
}

variable "vpn_instance_name" {
    type = string
}

variable "subnet_display_name" {
    type = string
}

variable "private_subnet_route_table_display_name" {
    type = string
}

variable "app_tags" {
    type = map(string)  
    default = null
}

variable "vnic_name" {
    type = string
}

variable "vcn_display_name"{
    type = string
    default = "OpenVPN VCN"
}

variable "vcn_state" {
    type = string  
    default = "Available"
}

variable "private_subnet_display_name" {
    type = string
}

variable "private_subnet_cidr_block" {
    type = string
}

variable "vpn_security_list_display_name" {
    type = string
}

variable "k8s_security_list_name" {
    type = string
}

variable "k8s_cp_private_ip" {
    type = string
}

variable "k8s_worker_private_ip" {
    type = string
}