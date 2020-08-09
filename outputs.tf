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