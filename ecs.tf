module "ecs" {
  source = "terraform-aws-modules/ecs/aws"

  cluster_name = "ecs-integrated"

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/aws-ec2"
      }
    }
  }

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
  }

  services = {
    ecsdemo = {
      cpu    = 1024
      memory = 4096

      # Container definition(s)
      container_definitions = {
        backendecs = {
          cpu       = 512
          memory    = 1024
          essential = true
          assign_public_ip  = false
          create_security_group = true
          create_task_exec_iam_role = true
          network_mode = "awsvpc"
          image     = "533267186928.dkr.ecr.eu-central-1.amazonaws.com/container-registry:dev-20240517085841"
          port_mappings = [
            {
              name          = "backendport"
              containerPort = 8080
              hostPort = 8080
              protocol      = "tcp"
            }
          ]
          healthcheck = {
            command     = ["CMD-SHELL", "curl -f http://localhost:8080/actuator/health || exit 1"]
            start_period = 60
            interval    = 30
            timeout     = 5
            retries     = 3
          }

          # Example image used requires access to write to root filesystem
          readonly_root_filesystem = false
          
          memory_reservation = 100
        }
      }

      load_balancer = {
        service = {
          target_group_arn = aws_lb_target_group.my_target_group.arn
          container_name   = "backendecs"
          container_port   = 8080
        }
      }

      subnet_ids = ["subnet-048141e600cf095a4"]
      security_group_rules = {
        ecs_security_group_ingress = {
          type                     = "ingress"
          from_port                = 8080
          to_port                  = 8080
          protocol                 = "tcp"
          description              = "Service port"
          cidr_blocks = ["0.0.0.0/0"]
        }
        egress_all = {
          type        = "egress"
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
    }
  }

  tags = {
    Environment = "Development"
    Project     = "Example"
  }
}

resource "aws_lb_target_group" "my_target_group" {
  name     = "target-group-ecs"
  port     = 8080  
  protocol = "HTTP"
  vpc_id   = "vpc-02d26c54a06f3d4c4"  # Replace with your VPC ID
  target_type = "ip"  # Set the target type to "ip" for Fargate tasks
  health_check {
    path                = "/actuator/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
  }
}


# other resource, no association to ecs
resource "aws_security_group" "ecs_security_group" {
  name        = "ecs-security-group"
  description = "Security group for ECS tasks"
  vpc_id      = "vpc-02d26c54a06f3d4c4"  # Replace with your VPC ID

  // Define your security group rules here
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Service port"
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

