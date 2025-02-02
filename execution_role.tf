data "aws_iam_policy_document" "ecs_cloudwatch_doc" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution_role" {
  count              = length(var.execution_role_arn) == 0 ? 1 : 0
  name_prefix        = "${var.deploy_env}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_cloudwatch_doc.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "ecs_instance_role_policy" {
  count  = length(var.execution_role_arn) == 0 ? 1 : 0
  name   = "${var.name}-ecs-instance-role-policy"
  role   = aws_iam_role.execution_role[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogStream",
          "logs:CreateLogGroup",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = "*"
      }
    ]
  })
}

locals {
  policy_arns = concat(
    var.additional_task_policy_arns,
    ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
  )
}

/**
 * This resource code seems pretty gross, but 'tis the way it has to be.
 *
 * If you were to use a for_each loop, the code would work cleanly like:
 * for_each = setunion(var.additional_task_policy_arns, ["arn:..."])
 *
 * The issue with that is that terraform doesn't then know how many resources
 * to create until the variable additional_task_policy_arns is fully realized,
 * which may be a computed value from the calling module. In that case, you
 * would have to use `-target other_targets.that.determine.the.var` before
 * you could create this resource, which is buggy and messes up CI.
 *
 * By forcing the calling module to pass an explicit count, we can always know how
 * many resources will be created at plan time.
 */
resource "aws_iam_role_policy_attachment" "ecs_role_policy" {
  count      = length(var.execution_role_arn) == 0 ? var.additional_task_policy_arns_count + 1 : 0
  role       = aws_iam_role.execution_role[0].name
  policy_arn = local.policy_arns[count.index]
}
