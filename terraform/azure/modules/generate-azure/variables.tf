variable "display_name" {
  type        = string
  description = "Display name for the Entra ID app registration"
  default     = "Generate"
}

variable "ingress_host" {
  type        = string
  description = "Public hostname for Generate; used to build the OIDC redirect URI"
}

variable "admin_user_id" {
  type        = string
  description = "Optional Entra user object ID to pre-assign the Administrator role"
  default     = ""
}
