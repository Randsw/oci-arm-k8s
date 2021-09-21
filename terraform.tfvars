ssh_key_public = "~/ya_rsa.pub"

ssh_key_private = "~/ya_rsa"

region = "eu-frankfurt-1" 

image_id = {
    eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaaymguk5srho2luw7w627fm3sshgtgpsfkzmeiec3qrrwsy3ys76fa" 
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

private_subnet_cidr_block = "172.16.1.0/24"

vpn_security_list_display_name = "OpenVPN security list"

k8s_security_list_name = "k8s security list"

k8s_cp_private_ip = "172.16.1.2"

k8s_worker_private_ip = "172.16.1.3"

openvpn_subnet_cidr = "10.9.0.0/24"

egress_rule = [{"protocol": "all", "destination": "0.0.0.0/0"},]

tcp_ingress_rule = [{"protocol": "6", "source": "0.0.0.0/0", "description": "Allow ssh", "port": "22"},]

udp_ingress_rule = [{"protocol": "17", "source": "0.0.0.0/0", "description": "Allow openvpn", "port": "1194"},]