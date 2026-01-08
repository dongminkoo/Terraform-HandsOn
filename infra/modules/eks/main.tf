# IAM Role for EKS Cluster Control Plane

resource "aws_iam_role" "eks_cluster" {
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = { Service = "eks.amazonaws.com" }
            }
        ]
    })
    tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
    role = aws_iam_role.eks_cluster.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

## EKS Cluster
resource "aws_eks_cluster" "this" {
    name = var.cluster_name
    role_arn = aws_iam_role.eks_cluster.arn
    version = var.k8s_version

    vpc_config {
        subnet_ids = var.subnet_ids
        endpoint_public_access = false
        endpoint_private_access = true
    }
    tags = var.tags
}

## IAM for Node Group
resource "aws_iam_role" "node" {
    name = "${var.cluster_name}-eks-node-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = { Service = "ec2.amazonaws.com"}
            }
        ]
    })
    tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
    role = aws_iam_role.node.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
    role = aws_iam_role.node.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
    role = aws_iam_role.node.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Managed Node Group

resource "aws_eks_node_group" "this" {
    cluster_name = aws_eks_cluster.this.name
    node_group_name = "${var.cluster_name}-ng"
    node_role_arn = aws_iam_role.node.arn
    subnet_ids = var.subnet_ids

    scaling_config {
        desired_size = 1
        min_size = 1
        max_size = 2
    }

    instance_types = ["t2.micro"]
    ami_type = "AL2_x86_64"

    tags = var.tags
}

