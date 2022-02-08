variable "name" {
  description = "The name of the service. Used as a prefix for other resource names"
}

variable "cluster_id" {
  description = <<EOF
  The id of the ECS cluster this service belongs to.

  Having multiple related services in one service can decrease cost
  by more efficiently using a shared pool of resources.
  EOF
}

variable "cluster_name" {
  type = string
  description = "The name of the ECS cluster this service will run in."
}

variable "desired_count" {
  type        = number
  description = "If not using Application Auto-scaling, the number of tasks to keep alive at all times"
  default     = null
}

variable "use_autoscaling" {
  type        = bool
  description = "Use Application Auto-scaling to scale service"
  default     = false
}

variable "min_desired_count" {
  type        = number
  description = "If using Application auto-scaling, minimum number of tasks to keep alive at all times"
  default     = null
}

variable "max_desired_count" {
  type        = number
  description = "If using Application auto-scaling, maximum number of tasks to keep alive at all times"
  default     = null
}

variable "scaling_target_value" {
  type        = number
  description = "If using Application auto-scaling, the target value to hit for the Auto-scaling policy"
  default     = null
}

variable "scaling_metric" {
  type        = string
  description = "If using Application auto-scaling, the pre-defined AWS metric to use for the Auto-scaling policy"
  default     = "ALBRequestCountPerTarget"
}

variable "vpc_id" {
  description = "ID of the VPC the alb is in"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnets tasks can be run in."
}

variable "load_balancers" {
  type = list(object({
    target_group_arn = string
    container_name   = string
    container_port   = string
  }))

  default     = []
  description = <<EOF
  When using ECS services, the service will ensure that at least
  {@variable desired_count} tasks are running at all times. Because
  there can be multiple tasks running at once, we set up a load
  balancer to ditribute traffic.

  `target_group_arn` is the arn of the target group on that alb that will
  be set to watch over the tasks managed by this service.
  EOF
}

variable "service_registries" {
  description = "Allows you to register this service to a Cloud Map registry"
  type        = list(map(string))
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags to set on all resources that support them"
}

variable "cpu" {
  default     = 512
  description = "How much CPU should be allocated to each app instance?"
}

variable "memory" {
  default     = 1024
  description = "How much memory should be allocated to each app instance?"
}

variable "container_definitions" {
  type        = string
  description = "JSON encoded list of container definitions"
}

variable "additional_task_policy_arns" {
  type        = list(string)
  description = "IAM Policy arns to be added to the tasks"
  default     = []
}

variable "additional_task_policy_arns_count" {
  type        = number
  description = "The number of items in var.additional_task_policy_arns. Terraform is not quite smart enough to figure this out on its own."
  default     = 0
}

variable "health_check_grace_period_seconds" {
  type        = number
  default     = 60
  description = "Seconds to ignore failing load balancer health checks on newly instantiated tasks to prevent premature shutdown, up to 2147483647. Only valid for services configured to use load balancers."
}

variable "alb_security_group_ids" {
  type        = list(string)
  description = "The ids of all security groups set on the ALB. We require that the tasks can only talk to the ALB"
}

variable "execution_role_arn" {
  type        = string
  description = "If present, this is the execution role that will be used for the ECS Tasks. If not present, a role will be created"
  default     = ""
}

variable "security_group_id" {
  type        = string
  description = "If present, this is the security group to apply to the ECS task. If not present, a security group will be created"
  default     = ""
}

variable "volumes" {
  type        = list(map(string))
  description = "List of volumes to make available to containers in this task."
  default     = []
}

variable "deploy_env" {
  type        = string
  description = "The environment resources are to be created in. Usually dev, staging, or prod"
}

variable "aws_region" {
  type        = string
  description = "The AWS region to create resources in."
  default     = "eu-west-1"
}

variable "capacity_provider_strategies" {
  type = list(object({
    base              = optional(number)
    capacity_provider = string
    weight            = number
  }))
  default     = []
  description = <<EOF
  Capacity provider strategy to use for the service

  base - Number of tasks, at a minimum, to run on the specified capacity provider. Only one capacity provider in a capacity provider strategy can have a base defined.
  capacity_provider - Short name of the capacity provider
  weight - Relative percentage of the total number of launched tasks that should use the specified capacity provider
  EOF
}

variable "ephemeral_storage_gib" {
  description = "The total amount, in GiB, of ephemeral storage to set for the task. The minimum supported value is 20 GiB and the maximum supported value is 200 GiB."
  type        = number
  default     = 20
}