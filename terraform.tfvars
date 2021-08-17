ssh_key_public = "~/ya_rsa.pub"

ssh_key_private = "~/ya_rsa"

region = "eu-frankfurt-1" 

image_id = {
    eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaaymguk5srho2luw7w627fm3sshgtgpsfkzmeiec3qrrwsy3ys76fa" #!!!!!!!!!!!!!!
}

compartment_name = "OpenVPN"

vpn_instance_name = "OpenVPN Server"

vnic_name = "OpenVPN VNIC"

vcn_display_name = "OpenVPN VCN"

subnet_display_name = "OpenVPN subnet"

private_subnet_route_table_display_name = "k8s-subnet-route"

app_tags = {
      "app" = "k8s"
    }

private_subnet_display_name = "k8s-subnet1"

private_subnet_cidr_block = "172.16.2.0/24"

vpn_security_list_display_name = "OpenVPN security list"

k8s_security_list_name = "k8s security list"

k8s_cp_private_ip = "172.16.2.2"

k8s_worker_private_ip = "172.16.2.3"