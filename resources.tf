provider "aws" {
    access_key = ""
    secret_key = ""
    region = "ca-central-1"
}

#VPC
resource "aws_vpc" "main" {
  cidr_block       = "${var.cidr_vpc}"
  enable_dns_hostnames = "true"

  tags = {
    Name = "onica-nginx-vpc"
  }
}

#Public and Private Subnets

resource "aws_subnet" "public-ca-central-1a" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "${var.cidr_subnet_public_a}"
  availability_zone = "ca-central-1a"
  // availability_zone_id = "cac1-az1"

  tags = {
    Name = "public-ca-central-1a"
    AZ = "a"
    SubnetType = "Public"
  }
}

resource "aws_subnet" "private-ca-central-1a" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "${var.cidr_subnet_private_a}"
  availability_zone = "ca-central-1a"
  // availability_zone_id = "cac1-az1"

  tags = {
    Name = "private-ca-central-1a"
    AZ = "a"
    SubnetType = "Private"
  }
}

resource "aws_subnet" "public-ca-central-1b" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "${var.cidr_subnet_public_b}"
  availability_zone = "ca-central-1b"
  // availability_zone_id = "cac1-az2"

  tags = {
    Name = "public-ca-central-1b"
    AZ = "b"
    SubnetType = "Public"
  }
}

resource "aws_subnet" "private-ca-central-1b" {
  vpc_id     = "${aws_vpc.main.id}"
  cidr_block = "${var.cidr_subnet_private_b}"
  availability_zone = "ca-central-1b"
  // availability_zone_id = "cac1-az2"

  tags = {
    Name = "private-ca-central-1b"
    AZ = "b"
    SubnetType = "Private"
  }
}

#Allowing internet into VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "vpc-main-igw"
  }
}

resource "aws_route_table" "igw-rt" {
  vpc_id = "${aws_vpc.main.id}"
  tags = {
    Name = "igw-rt"
  }
}

// resource "aws_route" "to_igw" {
//   route_table_id            = "${aws_route_table.igw-rt.id}"
//   destination_cidr_block    = "0.0.0.0/0"
//   gateway_id      = "${aws_internet_gateway.igw.id}"
// }

// resource "aws_main_route_table_association" "main-rtb" {
//   vpc_id         = "${aws_vpc.main.id}"
//   route_table_id = "${aws_route_table.igw-rt.id}"
// }

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }
}

resource "aws_route_table_association" "public-ca-central-1a" {
  subnet_id      = "${aws_subnet.public-ca-central-1a.id}"
  route_table_id = "${aws_route_table.igw-rt.id}"
}

resource "aws_route_table_association" "public-ca-central-1b" {
  subnet_id      = "${aws_subnet.public-ca-central-1b.id}"
  route_table_id = "${aws_route_table.igw-rt.id}"
}

#Security Group from Internet to Load Balancer
resource "aws_security_group" "allow_http" {
  name        = "allow-http"
  description = "Allow http inbound traffic"
  vpc_id = "${aws_vpc.main.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow-http"
  }
}

resource "aws_elb" "nginx-elb" {
  name               = "nginx-elb"
  // availability_zones = ["ca-central-1a", "ca-central-1a"]
    security_groups = [
    "${aws_security_group.elb_http.id}"
  ]
  subnets = [
    "${aws_subnet.public-ca-central-1a.id}",
    "${aws_subnet.public-ca-central-1b.id}"
  ]

  // access_logs {
  //   bucket        = "nginx-elb-logs"
  //   bucket_prefix = "logs"
  //   interval      = 60
  // }

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }

  cross_zone_load_balancing   = true
  // idle_timeout                = 400
  // connection_draining         = true
  // connection_draining_timeout = 400

  tags = {
    Name = "nginx-elb"
  }
}


#Launch Configuration for Ubuntu server
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_launch_configuration" "ubuntu_as_launch_config" {
  name_prefix   = "as-launch-config"
  image_id      = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  security_groups = ["${aws_security_group.allow_http.id}"]
  user_data     = "${(data.template_file.bootstrap_nginx.rendered)}"
//   user_data = <<USER_DATA
// #!/bin/bash
// yum update
// yum -y install nginx
// echo "$(curl http://169.254.169.254/latest/meta-data/local-ipv4)" > /usr/share/nginx/html/index.html
// chkconfig nginx on
// service nginx start
//   USER_DATA

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "elb_http" {
  name        = "elb_http"
  description = "Allow HTTP traffic to instances through Elastic Load Balancer"
  vpc_id = "${aws_vpc.main.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

resource "aws_autoscaling_group" "nginx_asg" {
  name                 = "nginx_asg"
  launch_configuration = "${aws_launch_configuration.ubuntu_as_launch_config.name}"
  vpc_zone_identifier  = ["${aws_subnet.public-ca-central-1b.id}, ${aws_subnet.public-ca-central-1a.id}"]
  load_balancers       = ["${aws_elb.nginx-elb.id}"]
  min_size             = 1
  desired_capacity = 2
  max_size             = 4
  health_check_type = "ELB"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "nginx_asg_policy" {
  name                   = "nginx_asg_policy"
  scaling_adjustment     = 4
  adjustment_type        = "ExactCapacity"
  cooldown               = 60
  autoscaling_group_name = "${aws_autoscaling_group.nginx_asg.name}"
}

data "template_file" "bootstrap_nginx" {
  template = "${file("${path.module}/data/bootstrap_nginx.sh")}"
}

resource "aws_autoscaling_policy" "nginx_asg_policy_up" {
  name = "nginx_asg_policy_up"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.nginx_asg.name}"
}

resource "aws_cloudwatch_metric_alarm" "nginx_asg_cpu_alarm_up" {
  alarm_name = "nginx_asg_cpu_alarm_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "60"

  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.nginx_asg.name}"
  }

  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions = ["${aws_autoscaling_policy.nginx_asg_policy_up.arn}"]
}

resource "aws_autoscaling_policy" "nginx_asg_policy_down" {
  name = "nginx_asg_policy_down"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = "${aws_autoscaling_group.nginx_asg.name}"
}

resource "aws_cloudwatch_metric_alarm" "nginx_asg_cpu_alarm_down" {
  alarm_name = "nginx_asg_cpu_alarm_down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "10"

  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.nginx_asg.name}"
  }

  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions = ["${aws_autoscaling_policy.nginx_asg_policy_down.arn}"]
}


// #Load Balancer for NGINX
// resource "aws_lb" "nginx-lb" {
//   name               = "nginx-lb"
//   internal           = false
//   load_balancer_type = "network"
// #  security_groups    = ["${aws_security_group.allow-http-lb.id}"]
//   subnets            = ["${aws_subnet.public-ca-central-1b.id}, ${aws_subnet.public-ca-central-1a.id}"]

//   enable_deletion_protection = true

//   tags = {
//     Name = "nginx-lb"
//     Environment = "production"
//   }
// }

// resource "aws_lb_listener" "nginx-lb-listener" {
//   load_balancer_arn = "${aws_lb.nginx-lb.arn}"
//   port              = "80"
//   protocol          = "HTTP"

//   default_action {
//     type             = "forward"
//     target_group_arn = "${aws_lb_target_group.nginx-lb-target-group.arn}"
//   }
// }

// #Target Group for Network Load Balancer
// resource "aws_lb_target_group" "nginx-lb-target-group" {
//   name        = "nginx-lb-target-group"
//   port        = 80
//   protocol    = "HTTP"
//   target_type = "ip"
//   vpc_id      = "${aws_vpc.main.id}"

//   health_check {
//     interval            = 10
//     path                = "/"
//     port                = "traffic-port"
//     protocol            = "HTTP"
//     timeout             = "3"
//     healthy_threshold   = "3"
//     unhealthy_threshold = "2"
//     matcher             = "200"
//   }
// }

// resource "aws_autoscaling_attachment" "asg_attachment_nginx_lb" {
//   autoscaling_group_name = "${aws_autoscaling_group.nginx_asg.id}"
//   alb_target_group_arn   = "${aws_lb_target_group.nginx-lb-target-group.arn}"
// }



#Security Group Rule that allows from Load Balancer to ASG
// resource "aws_security_group_rule" "allow_all" {
//   type            = "ingress"
//   from_port       = 80
//   to_port         = 80
//   protocol        = "tcp"
//   cidr_blocks = ["${aws_subnet.private-ca-central-1b.id}, ${aws_subnet.private-ca-central-1a.id}"]
//   security_group_id = "${aws_security_group.allow-http-lb.id}"
// }