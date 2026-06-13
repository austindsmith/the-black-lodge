resource "synology_core_package" "container_manager" {
  name = "ContainerManager"
}

resource "synology_container_project" "example" {
  name = "whoami"
  services = {
    whoami = {
      image = "traefik/whoami:latest"
      ports = [{ target = 80, published = 8080 }]
    }
  }
  depends_on = [synology_core_package.container_manager]
}
