variable "name" {type = string}

variable "vpc_cidr" {type = string}
variable "azs" {type = list(string)}

variable "public_subnet_cidrs" {type = list(string)} # web (LB)
variable "app_subnet_cidrs" {type = list(string)} # app (private)
variable "db_subnet_cidrs" {type = list(string)} # db (private)

variable "tags" {
    type = map(string)
    default = {}
}

variable "cluster_name" {
    type = string
    description = "EKS Cluster Name for subnet tagging"
}