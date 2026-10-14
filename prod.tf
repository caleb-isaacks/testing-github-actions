variable "ntfy_topic" {
  type      = string
  sensitive = true
  default   = "hubspoke-ops-7f3k9d2x"
}

variable "keyvault_name"{
    type = string
    default = "terraform-study-kv-01"
}

variable "key_vault_rg"{
    type = string
    default = "tf-state-remote"
}
