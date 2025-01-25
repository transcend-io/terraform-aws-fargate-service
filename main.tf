locals {
  security_group_id = length(var.security_group_id) > 0 ? var.security_group_id : aws_security_group.service_security_group[0].id
  role_arn          = length(var.execution_role_arn) > 0 ? var.execution_role_arn : aws_iam_role.execution_role[0].arn
}

resource "null_resource" "always_run" {
  triggers = {
    timestamp = "${timestamp()}"
  }
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

  dynamic "volume" {
    for_each = var.volumes

    content {
      name      = volume.value.name
      host_path = lookup(volume.value, "host_path", null)

      dynamic "efs_volume_configuration" {
        for_each = lookup(volume.value, "efs_volume_configuration", [])
        content {
          file_system_id          = lookup(efs_volume_configuration.value, "file_system_id", null)
          root_directory          = lookup(efs_volume_configuration.value, "root_directory", null)
          transit_encryption      = lookup(efs_volume_configuration.value, "transit_encryption", null)
          transit_encryption_port = lookup(efs_volume_configuration.value, "transit_encryption_port", null)

          dynamic "authorization_config" {
            for_each = lookup(efs_volume_configuration.value, "authorization_config", [])
            content {
              iam             = lookup(authorization_config.value, "iam", null)
              access_point_id = lookup(authorization_config.value, "access_point_id", null)
            }
          }
        }
      }
    }
  }

  ephemeral_storage {
    size_in_gib = var.ephemeral_storage_gib
  }

  lifecycle {
    replace_triggered_by = [
      null_resource.always_run
    ]
  }

  depends_on = [null_resource.always_run]
}

resource "aws_security_group" "service_security_group" {
  count       = length(var.security_group_id) == 0 ? 1 : 0
  name        = "${var.name}-ecs-security-group"
  description = "Allows inbound access to an ECS service only through its alb"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.load_balancers
    content {
      from_port       = ingress.value.container_port
      to_port         = ingress.value.container_port
      security_groups = can(length(ingress.value.security_groups)) ? ingress.value.security_groups : var.alb_security_group_ids
      cidr_blocks = can(length(ingress.value.cidr_blocks)) ? ingress.value.cidr_blocks : var.ingress_cidr_blocks
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

# Service, with no Auto-scaling configured.
resource "aws_ecs_service" "service_no_autoscaling" {
  count = var.use_autoscaling ? 0 : 1

  name          = var.name
  cluster       = var.cluster_id
  desired_count = var.desired_count

  task_definition = aws_ecs_task_definition.task.arn
  launch_type     = "FARGATE"

  enable_execute_command = var.enable_execute_command

  network_configuration {
    security_groups  = [local.security_group_id]
    subnets          = var.subnet_ids
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled   = var.service_connect_namespace != null
    namespace = var.service_connect_namespace
  }

  deployment_controller {
    type = "ECS"
  }

  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategies
    content {
      base              = capacity_provider_strategy.value.base
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = capacity_provider_strategy.value.weight
    }
  }

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
      container_name = lookup(service_registries.value, "container_name", null)
      container_port = lookup(service_registries.value, "container_port", null)
      port           = lookup(service_registries.value, "port", null)
    }
  }

  propagate_tags = "SERVICE"
  tags           = var.tags
}

# Service wth Auto-scaling configured.
resource "aws_ecs_service" "service_autoscaling" {
  count = var.use_autoscaling ? 1 : 0

  name          = var.name
  cluster       = var.cluster_id
  desired_count = var.min_desired_count

  task_definition = aws_ecs_task_definition.task.arn
  launch_type     = "FARGATE"

  enable_execute_command = var.enable_execute_command

  network_configuration {
    security_groups  = [local.security_group_id]
    subnets          = var.subnet_ids
    assign_public_ip = false
  }

  deployment_controller {
    type = "ECS"
  }

  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategies
    content {
      base              = capacity_provider_strategy.value.base
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = capacity_provider_strategy.value.weight
    }
  }

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
      container_name = lookup(service_registries.value, "container_name", null)
      container_port = lookup(service_registries.value, "container_port", null)
      port           = lookup(service_registries.value, "port", null)
    }
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  propagate_tags = "SERVICE"
  tags           = var.tags
}

resource "aws_appautoscaling_target" "ecs_service_autoscaling_target" {
  count = var.use_autoscaling ? 1 : 0

  min_capacity       = var.min_desired_count
  max_capacity       = var.max_desired_count
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.service_autoscaling[0].name}"
}

resource "aws_appautoscaling_policy" "ecs_service_autoscaling_policy" {
  count = var.use_autoscaling ? 1 : 0

  name               = "ecs-fargate-service-autoscaling-policy"
  service_namespace  = aws_appautoscaling_target.ecs_service_autoscaling_target[0].service_namespace
  scalable_dimension = aws_appautoscaling_target.ecs_service_autoscaling_target[0].scalable_dimension
  resource_id        = aws_appautoscaling_target.ecs_service_autoscaling_target[0].resource_id
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    # Seconds
    scale_in_cooldown = var.scale_in_cooldown
    # Seconds
    scale_out_cooldown = var.scale_out_cooldown
    target_value       = var.scaling_target_value
    predefined_metric_specification {
      predefined_metric_type = var.scaling_metric
      resource_label         = var.scaling_metric == "ALBRequestCountPerTarget" ? var.alb_scaling_target_resource_id : null
    }
  }
}
