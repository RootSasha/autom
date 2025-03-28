resource "aws_autoscaling_group" "jenkins_asg" {
  desired_capacity    = 1
  max_size            = 3
  min_size            = 1
  vpc_zone_identifier = [aws_subnet.main.id]

  launch_template {
    id      = aws_launch_template.instance_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "JenkinsAutoScaled"
    propagate_at_launch = true
  }
}