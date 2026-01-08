# VPC 생성
# VPC는 격리된 네트워크 환경을 제공하여 리소스 간 통신을 제어합니다
resource "aws_vpc" "this" {
    cidr_block = var.vpc_cidr
    # DNS 지원 활성화: VPC 내에서 DNS 쿼리 해결을 위해 필요
    enable_dns_support = true
    # DNS 호스트명 활성화: EC2 인스턴스에 DNS 호스트명을 부여하여 접근 가능하게 함
    enable_dns_hostnames = true
    tags = merge(var.tags, {Name = "${var.name}-vpc"})
}

# Internet Gateway 생성
# IGW는 VPC와 인터넷 간의 통신을 가능하게 하는 게이트웨이입니다
# Public 서브넷의 리소스가 인터넷에 접근하려면 IGW가 필요합니다
resource "aws_internet_gateway" "this" {
    vpc_id = aws_vpc.this.id
    tags = merge(var.tags, {Name = "${var.name}-igw"})
}

# Public Subnet 생성
# Public 서브넷은 인터넷과 직접 통신할 수 있는 서브넷입니다 (ALB, Bastion 등 배치)
resource "aws_subnet" "public" {
    count = length(var.public_subnet_cidrs)
    vpc_id = aws_vpc.this.id
    cidr_block = var.public_subnet_cidrs[count.index]
    # 가용 영역 분산: 고가용성을 위해 여러 AZ에 서브넷을 분산 배치
    availability_zone = var.azs[count.index]
    # 자동 퍼블릭 IP 할당: 인스턴스 생성 시 자동으로 퍼블릭 IP를 할당하여 인터넷 접근 가능
    map_public_ip_on_launch = true
    tags = merge(
        var.tags, {
                Name = "${var.name}-public-${var.azs[count.index]}"
                "kubernetes.io/cluster/${var.cluster_name}" = "shared"
                "kubernetes.io/role/elb" = 1
          }
        )
}

# App Subnet 생성 (Private)
# App 서브넷은 애플리케이션 서버를 배치하는 프라이빗 서브넷입니다
# 인터넷에 직접 노출되지 않아 보안이 강화됩니다
resource "aws_subnet" "app" {
    count = length(var.app_subnet_cidrs)
    vpc_id = aws_vpc.this.id
    cidr_block = var.app_subnet_cidrs[count.index]
    availability_zone = var.azs[count.index]
    tags = merge(
        var.tags, {
            Name = "${var.name}-app-${var.azs[count.index]}"
            "kubernetes.io/cluster/${var.cluster_name}" = "shared"
            "kubernetes.io/role/internal-elb" = 1
            }
        )
}

# DB Subnet 생성 (Private)
# DB 서브넷은 데이터베이스를 배치하는 가장 보안이 중요한 프라이빗 서브넷입니다
# 인터넷 접근이 완전히 차단되어 데이터베이스 보안을 최대화합니다
resource "aws_subnet" "db" {
    count = length(var.db_subnet_cidrs)
    vpc_id = aws_vpc.this.id
    cidr_block = var.db_subnet_cidrs[count.index]
    availability_zone = var.azs[count.index]
    tags = merge(var.tags, {Name = "${var.name}-db-${var.azs[count.index]}"})
}

# Route Tables 생성

# Public Route Table
# Public 서브넷의 트래픽을 인터넷으로 라우팅하기 위한 라우트 테이블
resource "aws_route_table" "public" {
    vpc_id = aws_vpc.this.id
    tags = merge(var.tags, {Name = "${var.name}-rtb-public"})
}

# Public 서브넷의 모든 트래픽(0.0.0.0/0)을 Internet Gateway로 라우팅
# 이를 통해 Public 서브넷의 리소스가 인터넷에 접근할 수 있습니다
resource "aws_route" "public_internet" {
    route_table_id = aws_route_table.public.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
}

# Public 서브넷을 Public 라우트 테이블에 연결
# 서브넷과 라우트 테이블을 연결해야 라우팅 규칙이 적용됩니다
resource "aws_route_table_association" "public" {
    count = length(aws_subnet.public)
    subnet_id = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.public.id
}

# App Route Table (Private)
# App 서브넷용 라우트 테이블 - 기본적으로 VPC 내부 통신만 허용
# NAT Gateway를 추가하면 인터넷 아웃바운드 접근도 가능합니다
resource "aws_route_table" "app" {
    vpc_id = aws_vpc.this.id
    tags = merge(var.tags, {Name = "${var.name}-rtb-app"})
}

resource "aws_route_table_association" "app" {
    count = length(aws_subnet.app)
    subnet_id = aws_subnet.app[count.index].id
    route_table_id = aws_route_table.app.id
}

# DB Route Table (Private)
# DB 서브넷용 라우트 테이블 - VPC 내부 통신만 허용하여 최대한 격리
# 인터넷 접근이 없어 데이터베이스 보안을 강화합니다
resource "aws_route_table" "db" {
    vpc_id = aws_vpc.this.id
    tags = merge(var.tags, {Name = "${var.name}-rtb-db"})
}

resource "aws_route_table_association" "db" {
    count = length(aws_subnet.db)
    subnet_id = aws_subnet.db[count.index].id
    route_table_id = aws_route_table.db.id
}

# Security Group 생성
# Security Group은 가상 방화벽 역할을 하여 인바운드/아웃바운드 트래픽을 제어합니다

# ALB Security Group
# Application Load Balancer에 적용되는 보안 그룹
# 인터넷에서 접근 가능하므로 Public 서브넷에 배치됩니다
resource "aws_security_group" "alb" {
    name = "${var.name}-alb-sg"
    description = "ALB SG (public)"
    vpc_id = aws_vpc.this.id
    tags = merge(var.tags, {Name = "${var.name}-alb-sg"})
}

# App Security Group
# 애플리케이션 서버에 적용되는 보안 그룹
# ALB에서만 접근 가능하도록 제한하여 보안을 강화합니다
resource "aws_security_group" "app" {
    name = "${var.name}-app-sg"
    description = "App SG (Private)"
    vpc_id = aws_vpc.this.id
    tags = merge(var.tags, {Name = "${var.name}-app-sg"})
}

# Security Group Rules

# ALB 인바운드 규칙: HTTP(포트 80) 허용
# 인터넷의 모든 IP(0.0.0.0/0)에서 ALB로의 HTTP 요청을 허용합니다
# 웹 애플리케이션에 대한 공개 접근을 제공합니다
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
    security_group_id = aws_security_group.alb.id
    description = "HTTP from Internet"
    ip_protocol = "tcp"
    from_port = 80
    to_port = 80
    cidr_ipv4 = "0.0.0.0/0"
}

# ALB 아웃바운드 규칙: 모든 트래픽 허용
# ALB가 백엔드 App 서버로 요청을 전달하고 응답을 받기 위해 필요합니다
# 프로토콜 "-1"은 모든 프로토콜을 의미합니다
resource "aws_vpc_security_group_egress_rule" "alb_all_out" {
    security_group_id = aws_security_group.alb.id
    description = "All outbound"
    ip_protocol = "-1"  # any
    cidr_ipv4 = "0.0.0.0/0"
}

# App 인바운드 규칙: ALB에서만 접근 허용
# App 서버는 ALB Security Group에서만 포트 8080으로 접근 가능합니다
# 인터넷에서 직접 접근할 수 없어 보안이 강화됩니다
# referenced_security_group_id를 사용하여 ALB SG의 트래픽만 허용합니다
resource "aws_vpc_security_group_ingress_rule" "app_from_alb_8080" {
    security_group_id = aws_security_group.app.id
    description = "App from ALB"
    ip_protocol = "tcp"
    from_port = 8080
    to_port = 8080
    referenced_security_group_id = aws_security_group.alb.id
}

# App 아웃바운드 규칙: 모든 트래픽 허용
# App 서버가 외부 API 호출, 패키지 다운로드 등을 위해 필요합니다
# DB 접근을 위해서도 아웃바운드 규칙이 필요합니다
resource "aws_vpc_security_group_egress_rule" "app_all_out" {
    security_group_id = aws_security_group.app.id
    description = "All outbound"
    ip_protocol = "-1"
    cidr_ipv4 = "0.0.0.0/0"
}