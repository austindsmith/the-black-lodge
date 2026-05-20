inputs = {
  ram       = 8192
  cpu_type  = "host"
  vlan_id   = 5
  template_id = 9000

  nodes = {
    kubernetes_server_01 = { vm_id = 8001, ip = "192.168.100.15/24" }
    kubernetes_server_02 = { vm_id = 8002, ip = "192.168.100.16/24" }
  }
}
