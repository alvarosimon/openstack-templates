locals {
  both_enabled = var.nfs_enabled && var.nginx_enabled
  any_enabled  = var.nfs_enabled || var.nginx_enabled
  ports = {
    ssh  = jsondecode(shell_script.port_ssh.output["ports"])[0]
    http = var.nginx_enabled ? jsondecode(shell_script.port_http[0].output["ports"])[0] : null
  }
  is_windows        = contains(["Windows10", "Windows-11"], var.image_name)
  ssh_internal_port = local.is_windows ? 3389 : 22
  project_name      = var.project_name == "default" ? data.shell_script.project.output["Name"] : var.project_name
  access_key        = var.access_key == "default" ? data.shell_script.access_key.output["Name"] : var.access_key
}
resource "shell_script" "port_ssh" {
  environment = {
    "IP_ID"      = data.openstack_networking_floatingip_v2.public.id
    "PORT_COUNT" = 1
    "PORT_NAME"  = "${var.vm_name}-${substr(openstack_compute_instance_v2.instance_01.id, 0, 4)}_ssh"
    "OS_CLOUD"   = var.cloud
  }
  lifecycle_commands {
    create = file("../scripts/generate_port.sh")
    delete = <<-EOF
      rm -rf "port_${var.vm_name}-${substr(openstack_compute_instance_v2.instance_01.id, 0, 4)}_ssh.json"
    EOF
    read   = <<-EOF
      cat "port_${var.vm_name}-${substr(openstack_compute_instance_v2.instance_01.id, 0, 4)}_ssh.json"
    EOF
  }
  working_directory = path.root
  interpreter       = ["/bin/bash", "-c"]
}
resource "shell_script" "port_http" {
  count = var.nginx_enabled ? 1 : 0
  environment = {
    "OS_CLOUD"   = var.cloud
    "IP_ID"      = data.openstack_networking_floatingip_v2.public.id
    "PORT_COUNT" = 1
    "PORT_NAME"  = "${var.vm_name}-${substr(openstack_compute_instance_v2.instance_01.id, 0, 4)}_http"
  }
  lifecycle_commands {
    create = file("../scripts/generate_port.sh")
    delete = <<-EOF
      rm -rf "port_${var.vm_name}-${substr(openstack_compute_instance_v2.instance_01.id, 0, 4)}_http.json"
    EOF
    read   = <<-EOF
      cat "port_${var.vm_name}-${substr(openstack_compute_instance_v2.instance_01.id, 0, 4)}_http.json"
    EOF
  }
  working_directory = path.root
  interpreter       = ["/bin/bash", "-c"]
}
data "shell_script" "project" {
  environment = {
    OS_CLOUD = var.cloud
  }
  lifecycle_commands {
    read = <<EOF
openstack project list -f json | jq '.[0]'
    EOF
  }
}
data "shell_script" "access_key" {
  environment = {
    OS_CLOUD = var.cloud
  }
  lifecycle_commands {
    read = <<EOF
openstack keypair list -f json | jq '.[0]'
    EOF
  }
}
data "openstack_networking_network_v2" "vm" {
  name = "${local.project_name}_vm"
}
data "openstack_networking_subnet_ids_v2" "vm" {
  network_id = data.openstack_networking_network_v2.vm.id
}
data "openstack_compute_flavor_v2" "flavor" {
  name = var.flavor_name
}
data "openstack_images_image_ids_v2" "image" {
  name = var.image_name
}
data "openstack_networking_network_v2" "public" {
  name = "public"
}
data "openstack_networking_floatingip_v2" "public" {
  pool = data.openstack_networking_network_v2.public.id
}
resource "random_string" "winpass" {
  count   = local.is_windows ? 1 : 0
  length  = 16
  special = false
}
