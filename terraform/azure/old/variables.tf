variable "display_name" {
  description = "Display name for the Entra app registration"
  type        = string
  default     = "Generate"
}

variable "ingress_host" {
  description = "Public hostname of the Generate ingress (e.g. generate.theblacklodge.dev)"
  type        = string
}

variable "admin_user_id" {
  description = "Object ID of the Entra user to assign the Administrator app role"
  type        = string
  default     = null
}
