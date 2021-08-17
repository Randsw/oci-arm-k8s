data "sops_file" "secret" {
  source_file = "secret_dep.sops.yaml"
}

provider "oci" {
  region           = data.sops_file.secret.data["region"]
  tenancy_ocid     = data.sops_file.secret.data["tenancy"]
  user_ocid        = data.sops_file.secret.data["user"]
  fingerprint      = data.sops_file.secret.data["fingerprint"]
  private_key_path = data.sops_file.secret.data["key_file"]
}