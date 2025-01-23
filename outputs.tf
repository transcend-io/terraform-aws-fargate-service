output "role_arn" {
  value       = local.role_arn
  description = "Arn of the task execution role"
}

output "policy_arns" {
  value       = local.policy_arns
  description = "Amazon resource names of all policies set on the IAM Role execution task"
}

output "task_arn" {
  value       = aws_ecs_task_definition.task.arn
  description = "Task family and revision for the latest deployed Task Definition"
}

output "task_family" {
  value       = aws_ecs_task_definition.task.family
  description = "Task family of the ECS Task Definition used by this ECS Service"
}

output "service_sg_id" {
  value       = local.security_group_id
  description = "ID of the security group set on this ECS Service"
}