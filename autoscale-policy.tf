# # scale up alarm
# resource "aws_autoscaling_policy" "simpleserverpolicy" {
#   name                   = "simpleserverpolicy"
#   autoscaling_group_name = aws_autoscaling_group.simpleserverautoscaling.name
#   adjustment_type        = "ChangeInCapacity"
#   scaling_adjustment     = "1"
#   cooldown               = "300"
#   policy_type            = "SimpleScaling"
# }
# resource "aws_cloudwatch_metric_alarm" "simpleserveralarm" {
#   alarm_name          = "simpleserveralarm"
#   alarm_description   = "simpleserveralarm"
#   comparison_operator = "GreaterThanOrEqualToThreshold"
#   evaluation_periods  = "2"
#   metric_name         = "CPUUtilization"
#   namespace           = "AWS/EC2"
#   period              = "120"
#   statistic           = "Average"
#   threshold           = "30"

#   dimensions = {
#     "AutoScalingGroupName" = aws_autoscaling_group.simpleserverautoscaling.name
#   }

#   actions_enabled = true
#   alarm_actions   = [aws_autoscaling_policy.simpleserverpolicy.arn]
# }

# # scale down alarm
# resource "aws_autoscaling_policy" "simpleserverpolicy-scaledown" {
#   name                   = "simpleserverpolicy-scaledown"
#   autoscaling_group_name = aws_autoscaling_group.simpleserverautoscaling.name
#   adjustment_type        = "ChangeInCapacity"
#   scaling_adjustment     = "-1"
#   cooldown               = "300"
#   policy_type            = "SimpleScaling"
# }

# resource "aws_cloudwatch_metric_alarm" "simpleserveralarm-scaledown" {
#   alarm_name          = "simpleserveralarm-scaledown"
#   alarm_description   = "simpleserveralarm-scaledown"
#   comparison_operator = "LessThanOrEqualToThreshold"
#   evaluation_periods  = "2"
#   metric_name         = "CPUUtilization"
#   namespace           = "AWS/EC2"
#   period              = "120"
#   statistic           = "Average"
#   threshold           = "5"

#   dimensions = {
#     "AutoScalingGroupName" = aws_autoscaling_group.simpleserverautoscaling.name
#   }

#   actions_enabled = true
#   alarm_actions   = [aws_autoscaling_policy.simpleserverpolicy-scaledown.arn]
# }

# resource "aws_sns_topic" "cloudreach-sns" {
#   name         = "sg-sns"
#   display_name = "cloudreach ASG SNS topic"
# } # email subscription is currently unsupported in terraform and can be done using the AWS Web Console

# resource "aws_autoscaling_notification" "cloudreach-notify" {
#   group_names = ["${aws_autoscaling_group.simpleserverautoscaling.name}"]
#   topic_arn   = aws_sns_topic.cloudreach-sns.arn
#   notifications = [
#     "autoscaling:EC2_INSTANCE_LAUNCH",
#     "autoscaling:EC2_INSTANCE_TERMINATE",
#     "autoscaling:EC2_INSTANCE_LAUNCH_ERROR"
#   ]
# }