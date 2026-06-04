data "cloudinit_config" "generate" {
  gzip          = false
  base64_encode = false

  part {
    filename     = "initialize-disks.ps1"
    content_type = "text/x-shellscript"
    content      = <<-EOF
      #ps1_sysnative
      Get-Disk `
        | Where-Object {$_.PartitionStyle -eq 'RAW'} `
        | ForEach-Object {
          $_ `
            | Initialize-Disk -PartitionStyle GPT -PassThru `
            | New-Partition -AssignDriveLetter -UseMaximumSize `
            | Format-Volume -FileSystem NTFS -NewFileSystemLabel "data$($_.Number)" -Confirm:$false
        }
    EOF
  }

  part {
    content_type = "text/cloud-config"
    content      = <<-EOF
      #cloud-config
      hostname: ${var.prefix}
      timezone: ${var.timezone}
      users:
        - name: ${jsonencode(var.username)}
          passwd: ${jsonencode(var.password)}
          primary_group: Administrators
          ssh_authorized_keys:
            - ${jsonencode(trimspace(file(var.ssh_public_key_path)))}
    EOF
  }
}

resource "proxmox_virtual_environment_file" "generate_ci_user_data" {
  content_type = "snippets"
  datastore_id = var.snippets_datastore_id
  node_name    = var.proxmox_node_name
  source_raw {
    file_name = "${var.prefix}-ci-user-data.txt"
    data      = data.cloudinit_config.generate.rendered
  }
}
