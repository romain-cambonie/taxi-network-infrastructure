resource "aws_lb" "api_load_balancer" {
  name               = "api-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.security_group_fargate.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]

  enable_deletion_protection = true

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "load_balancer_target_group" {
  name     = "load-balancer-target-group"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = aws_vpc.taxi_aymeric_vpc.id
}

resource "aws_lb_listener" "api_listener" {
  load_balancer_arn = aws_lb.api_load_balancer.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.acm_certificate.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.load_balancer_target_group.arn
  }
}
