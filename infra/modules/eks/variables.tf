variable "cluster_name" {type = string}
variable "vpc_id" {type = string}
variable "subnet_ids" {type = list(string)}

variable "k8s_version" {
    type = string
    default = "1.29"
}

variable "tags" {
    type = map(string)
    default = {}
}