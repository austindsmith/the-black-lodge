variable "display_name" {
  type        = string
  description = "Display name for the Entra ID app registration"
  default     = "Generate"
}

variable "ingress_host" {
  type        = string
  description = "Public hostname for Generate; used to build the SPA redirect URI"
}

variable "administrator_object_ids" {
  type        = list(string)
  description = "Entra user object IDs to assign the Administrator app role"
  default     = []
}

variable "reviewer_object_ids" {
  type        = list(string)
  description = "Entra user object IDs to assign the Reviewer app role"
  default     = []
}
