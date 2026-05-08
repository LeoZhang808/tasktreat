###############################################################################
# RDS module
#
# Creates a single PostgreSQL RDS instance inside private subnets, with a
# security group that only accepts inbound traffic from the supplied
# application security groups (typically the EKS cluster SG). The DB is
# deliberately not publicly accessible.
###############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db-subnets"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db-subnets"
  })
}

resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "PostgreSQL access for ${var.name_prefix} RDS, restricted to the application layer."
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds-sg"
  })
}

# One inbound rule per allowed source security group. The for_each map uses
# static labels as keys (e.g. "eks-cluster") so the plan can be computed
# without knowing the actual SG IDs yet -- those come from other resources
# in the same apply (the EKS cluster) and are unknown at plan time.
resource "aws_security_group_rule" "rds_ingress_from_app" {
  for_each = var.allowed_security_groups

  type                     = "ingress"
  description              = "PostgreSQL from ${each.key}"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  source_security_group_id = each.value
  security_group_id        = aws_security_group.rds.id
}

resource "aws_security_group_rule" "rds_egress_all" {
  type              = "egress"
  description       = "Allow all outbound traffic from the RDS instance."
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id
}

resource "aws_db_instance" "this" {
  identifier     = "${var.name_prefix}-postgres"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage_gb
  max_allocated_storage = var.max_allocated_storage_gb
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = var.db_port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = var.publicly_accessible
  multi_az               = var.multi_az

  backup_retention_period = var.backup_retention_period
  copy_tags_to_snapshot   = true
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot
  final_snapshot_identifier = (
    var.skip_final_snapshot
    ? null
    : "${var.name_prefix}-postgres-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  )

  performance_insights_enabled = var.performance_insights_enabled

  auto_minor_version_upgrade = true
  apply_immediately          = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-postgres"
  })

  lifecycle {
    # final_snapshot_identifier uses timestamp() which would otherwise force
    # a new resource on every plan.
    ignore_changes = [final_snapshot_identifier]
  }
}
