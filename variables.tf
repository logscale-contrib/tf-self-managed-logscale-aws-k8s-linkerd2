variable "eks_cluster_id" {
  type        = string
  description = "(optional) describe your variable"
}
variable "eks_endpoint" {
  type        = string
  description = "(optional) describe your variable"
}
variable "eks_cluster_certificate_authority_data" {
  type        = string
  description = "(optional) describe your variable"
}
variable "eks_oidc_provider_arn" {
  type        = string
  description = "(optional) describe your variable"
}


variable "domain_is_private" {
  type        = bool
  default     = false
  description = "(optional) describe your variable"
}
variable "domain_name" {
  type        = string
  description = "(optional) describe your variable"
}
