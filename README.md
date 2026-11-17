# terraform-aws-fargate-service

Terraform module for running an application on [AWS ECS Fargate](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html), including optional load balancer attachment, service discovery, auto-scaling, and Service Connect.

Published versions are tagged in this repository (for example `v0.10.0`) and consumed via the [Terraform Registry](https://registry.terraform.io/modules/transcend-io/fargate-service/aws).

## VPC Lattice (optional)

ECS can register task ENI IP addresses with a VPC Lattice **IP** target group when `vpc_lattice_configurations` is set on the service. See [Use Amazon ECS with VPC Lattice](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/vpc-lattice.html).

- **Default:** `vpc_lattice_configurations = []` — no Lattice blocks are created (no behavior change vs prior releases).
- **`port_name`:** Must match a **named** `portMappings` entry in the task definition (`container_definitions` JSON).
- **`role_arn`:** The [ECS infrastructure IAM role for VPC Lattice](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/infrastructure_IAM_role.html). Callers create and pass this role; this module does not create Lattice resources or IAM.
- **`additional_ingress_rules`:** Optional inline ingress on the primary task SG (for example VPC Lattice managed prefix-list → task port). Prefer this over a second SG or standalone `aws_vpc_security_group_ingress_rule` on the primary SG (inline + standalone conflict).

Example (values are illustrative):

```hcl
vpc_lattice_configurations = [
  {
    target_group_arn = module.lattice_target_group.arn
    port_name        = "http"
    role_arn         = var.ecs_infrastructure_role_arn
  },
]
```

Each entry needs `target_group_arn`, `port_name`, and `role_arn`.
