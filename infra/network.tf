# Default VPC and Subnets
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_default_vpc" "default" {
  tags = merge(
    local.common_tags,
    {
      Name = "Default VPC"
    }
  )
}

resource "aws_default_subnet" "default" {
  count             = 2
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    local.common_tags,
    {
      Name = "Default Subnet ${count.index + 1}"
    }
  )
}
