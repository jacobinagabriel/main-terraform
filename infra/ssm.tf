# Published values that app repos read with `data "aws_ssm_parameter"`, so they never
# depend on this repo's state. Paths: /<project_name>/<env>/<group>/<name>.
locals {
  ssm_prefix = "/${var.project_name}/${var.env}"

  network_parameters = {
    vpc_id             = { type = "String", value = module.vpc.vpc_id }
    vpc_cidr           = { type = "String", value = module.vpc.vpc_cidr_block }
    azs                = { type = "StringList", value = join(",", var.azs) }
    public_subnet_ids  = { type = "StringList", value = join(",", module.vpc.public_subnets) }
    private_subnet_ids = { type = "StringList", value = join(",", module.vpc.private_subnets) }
  }
}

resource "aws_ssm_parameter" "network" {
  for_each = local.network_parameters

  name  = "${local.ssm_prefix}/network/${each.key}"
  type  = each.value.type
  value = each.value.value

  tags = local.common_tags
}
