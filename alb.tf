resource "aws_lb" "api_load_balancer" {
  name               = "api-load-balancer"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.security_group_api_load_balancer.id]
  subnets            = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  enable_deletion_protection = false

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "load_balancer_target_group_api" {
  name        = "load-balancer-api-target-group"
  target_type = "ip"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.taxi_aymeric_vpc.id

  health_check {
    path     = "/"
    protocol = "HTTP"
    matcher  = "200"

  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "api_listener_http" {
  load_balancer_arn = aws_lb.api_load_balancer.arn
  port              = "80"
  protocol          = "HTTP"

  //  default_action {
  //    type = "fixed-response"
  //
  //    fixed_response {
  //      content_type = "application/json"
  //      message_body = "{ message: Progress Baby }"
  //      status_code  = "200"
  //    }
  //  }
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.load_balancer_target_group_api.arn
  }
}
