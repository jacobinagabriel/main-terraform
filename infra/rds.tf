resource "aws_db_subnet_group" "postgres" {
  name       = "${var.account_name}-${var.env}-postgres-subnet-group"
  subnet_ids = aws_default_subnet.default[*].id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.account_name}-${var.env}-postgres-subnet-group"
    }
  )
}

resource "aws_security_group" "postgres" {
  name        = "${var.account_name}-${var.env}-postgres-sg"
  description = "Security group for PostgreSQL RDS instance"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    description = "PostgreSQL access"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.account_name}-${var.env}-postgres-sg"
    }
  )
}

resource "aws_db_instance" "postgres" {
  identifier             = "${var.account_name}-${var.env}-postgres-db"
  engine                 = "postgres"
  engine_version         = "16.3"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  
  db_name  = "maindb"
  username = "dbadmin"
  password = var.db_password
  
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.postgres.id]
  
  publicly_accessible    = true
  skip_final_snapshot    = true
  
  backup_retention_period = 0
  multi_az               = false
  
  tags = merge(
    local.common_tags,
    {
      Name = "${var.account_name}-${var.env}-postgres-db"
    }
  )
}

output "rds_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_database_name" {
  description = "The name of the database"
  value       = aws_db_instance.postgres.db_name
}

output "rds_username" {
  description = "The master username for the database"
  value       = aws_db_instance.postgres.username
  sensitive   = true
}
