data "aws_instances" "jenkins" {
  filter {
    name   = "tag:Name"
    values = ["JenkinsAutoScaled"]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  depends_on = [aws_autoscaling_group.jenkins_asg]
}

output "public_ip" {
  description = "Public IP of the first running Jenkins instance"
  value       = length(data.aws_instances.jenkins.ids) > 0 ? element(data.aws_instances.jenkins.public_ips, 0) : "No instances found"
}