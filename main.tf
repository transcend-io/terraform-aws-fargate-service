resource "aws_ecs_service" "service" {
  name          = var.name
  cluster       = var.cluster_id
  desired_count = var.desired_count

  task_definition = aws_ecs_task_definition.task.arn
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.service_security_group.id]
    subnets          = var.subnet_ids
    assign_public_ip = false
  }

  deployment_controller {
    type = "ECS"
  }

  health_check_grace_period_seconds = length(var.load_balancers) > 0 ? 60 : 0

  dynamic "load_balancer" {
    for_each = var.load_balancers
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.container_port
    }
  }

  dynamic "service_registries" {
    for_each = var.service_registries
    content {
      registry_arn   = service_registries.value.registry_arn
      container_name = service_registries.value.container_name
      container_port = service_registries.value.container_port
    }
  }

  propagate_tags = "SERVICE"
  tags           = var.tags
}

locals {
  role_arn = length(var.execution_role_arn) > 0 ? var.execution_role_arn : aws_iam_role.execution_role[0].arn
}

resource "aws_ecs_task_definition" "task" {
  family                   = "${var.name}-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = local.role_arn
  task_role_arn            = local.role_arn
  container_definitions    = var.container_definitions
  tags                     = var.tags
}

resource "aws_security_group" "service_security_group" {
  name        = "${var.name}-ecs-security-group"
  description = "Allows inbound access to an ECS service only through its alb"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.load_balancers
    content {
      from_port       = ingress.value.container_port
      to_port         = ingress.value.container_port
      security_groups = var.alb_security_group_ids
      protocol        = "tcp"
    }
  }

  # Allow all outgoing access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  timeouts {
    create = "45m"
    delete = "45m"
  }

  tags = var.tags
}
