resource "aws_vpc" "taxi_aymeric_vpc" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, { "Name" = "taxi-aymeric-vpc" })
}

resource "aws_security_group" "security_group_api_load_balancer" {
  name        = "security-group-api-load-balancer"
  description = "Allow http and https inbound traffic"
  vpc_id      = aws_vpc.taxi_aymeric_vpc.id

  tags = merge(local.tags, { "Name" = "security-group-api-load-balancer" })

  lifecycle {
    # Necessary if changing 'name' or 'name_prefix' properties.
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allow_http_from_api_gateway" {
  type              = "ingress"
  description       = "Allow incoming HTTP traffic from anyone"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.security_group_api_load_balancer.id
}

// TODO Restrict to ecs service
resource "aws_security_group_rule" "allow_outgoing_to_ecs_service" {
  description       = "Load balancer to target service"
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.security_group_api_load_balancer.id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.taxi_aymeric_vpc.id

  tags = local.tags
}

# Get available zones for this account
data "aws_availability_zones" "available" {
  state = "available"
}

# Create subnets in the first two available availability zones
resource "aws_subnet" "public_1" {
  availability_zone       = data.aws_availability_zones.available.names[0]
  vpc_id                  = aws_vpc.taxi_aymeric_vpc.id
  map_public_ip_on_launch = true
  cidr_block              = "10.0.0.0/24"
  tags                    = merge(local.tags, { "Name" = "public_1" })
}

resource "aws_subnet" "private_1" {
  availability_zone       = data.aws_availability_zones.available.names[0]
  vpc_id                  = aws_vpc.taxi_aymeric_vpc.id
  map_public_ip_on_launch = false
  cidr_block              = "10.0.1.0/24"
  tags                    = merge(local.tags, { "Name" = "private_1" })
}

resource "aws_subnet" "public_2" {
  availability_zone       = data.aws_availability_zones.available.names[1]
  vpc_id                  = aws_vpc.taxi_aymeric_vpc.id
  map_public_ip_on_launch = true
  cidr_block              = "10.0.2.0/24"
  tags                    = merge(local.tags, { "Name" = "public_2" })
}

resource "aws_subnet" "private_2" {
  availability_zone       = data.aws_availability_zones.available.names[1]
  vpc_id                  = aws_vpc.taxi_aymeric_vpc.id
  map_public_ip_on_launch = false
  cidr_block              = "10.0.3.0/24"
  tags                    = merge(local.tags, { "Name" = "private_2" })
}

# Create route-tables
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.taxi_aymeric_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = local.tags
}

# Associate table with public subnet
resource "aws_route_table_association" "public_1_route_association" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_2_route_association" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Open connexion for the migration data transfer
resource "aws_route_table_association" "route_association_open_rds" {
  count          = var.openRdsToPublicInternet ? 1 : 0
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.public_route_table.id
}