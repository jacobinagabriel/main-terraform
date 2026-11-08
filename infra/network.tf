# Shared VPC for every project in the account.
#
# Idle cost is zero: subnets, the internet gateway, route tables and the S3 gateway
# endpoint are free. App tasks run in public subnets with a public IP and no inbound
# rules; databases go in private subnets. A NAT gateway (~$33/month) and interface
# endpoints (~$7.30/month each per AZ) are opt-in.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name = "${var.account_name}-${var.env}"
  cidr = var.vpc_cidr
  azs  = var.azs

  # /20 per subnet: public from the bottom of the range, private from the middle.
  public_subnets  = [for i, _ in var.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnets = [for i, _ in var.azs : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  enable_dns_hostnames    = true
  enable_dns_support      = true
  map_public_ip_on_launch = false # tasks ask for a public IP explicitly

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = true

  # Strip all rules from the default security group so nothing uses it by accident.
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  public_subnet_tags  = { tier = "public" }
  private_subnet_tags = { tier = "private" }

  tags = local.common_tags
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(module.vpc.public_route_table_ids, module.vpc.private_route_table_ids)

  tags = merge(local.common_tags, { Name = "${var.account_name}-${var.env}-s3" })
}

resource "aws_security_group" "endpoints" {
  count = length(var.interface_endpoints) > 0 ? 1 : 0

  name        = "${var.account_name}-${var.env}-vpc-endpoints"
  description = "HTTPS from inside the VPC to the interface endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS from the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(local.common_tags, { Name = "${var.account_name}-${var.env}-vpc-endpoints" })
}

resource "aws_vpc_endpoint" "interface" {
  for_each = toset(var.interface_endpoints)

  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, { Name = "${var.account_name}-${var.env}-${each.value}" })
}
