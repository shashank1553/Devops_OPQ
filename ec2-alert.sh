#!/bin/bash
set -e

# EC2 instance IDs for the four microservices
INSTANCE_IDS=("i-015dbc7ba0f3b79cf" "i-0c6ca49981a92c173" "i-0c40a295f2819c25d" "i-061135d6af49e4a29")

# Thresholds
CPU_THRESHOLD=50          # Percentage
DISK_THRESHOLD=50         # Percentage
LATENCY_THRESHOLD=80     # In milliseconds

# SNS Topic ARN (Amazon Resource Name) for email or other notifications
SNS_TOPIC_ARN="arn:aws:sns:us-east-1:585008047024:EC2_Alert"

# Slack Webhook URL for Slack notifications
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/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"

# Function to send alert via SNS
send_sns_alert() {
  local subject="$1"
  local message="$2"
  
  # Publish message to SNS
  aws sns publish \
    --topic-arn "$SNS_TOPIC_ARN" \
    --subject "$subject" \
    --message "$message"
}

# Function to send a Slack alert
send_slack_alert() {
  local message="$1"
  
  # Send message to Slack
  curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"$message\"}" "$SLACK_WEBHOOK_URL"
}

# Function to monitor metrics for a single instance
monitor_instance() {
  local instance_id="$1"

  # Get CPU utilization (avg over last minute)
  cpu_util=$(aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name CPUUtilization --dimensions Name=InstanceId,Value=$instance_id --statistics Average --period 60 --start-time $(date -u -d '-1 minute' +%Y-%m-%dT%H:%M:%SZ) --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) --query "Datapoints[0].Average" --output text)
  
  # Get Disk utilization (for root volume - example assumes one EBS volume)
  disk_util=$(aws cloudwatch get-metric-statistics --namespace AWS/EBS --metric-name VolumeUtilization --dimensions Name=VolumeId,Value=$(aws ec2 describe-instances --instance-id $instance_id --query "Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId" --output text) --statistics Average --period 300 --start-time $(date -u -d '-5 minutes' +%Y-%m-%dT%H:%M:%SZ) --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) --query "Datapoints[0].Average" --output text)
  
  # Get Network latency (avg over last 5 mins)
  latency=$(aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name NetworkPacketsOut --dimensions Name=InstanceId,Value=$instance_id --statistics Average --period 300 --start-time $(date -u -d '-5 minutes' +%Y-%m-%dT%H:%M:%SZ) --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) --query "Datapoints[0].Average" --output text)

  # Check if any metrics exceed thresholds using awk for comparison
  if [ "$(echo "$cpu_util > $CPU_THRESHOLD" | awk '{if ($1) print 1; else print 0}')" -eq 1 ]; then
    subject="High CPU Utilization on $instance_id"
    message="Instance $instance_id has CPU utilization of $cpu_util%, exceeding the threshold of $CPU_THRESHOLD%."
    send_sns_alert "$subject" "$message"
    send_slack_alert "⚠️ High CPU Utilization: Instance $instance_id has CPU utilization of $cpu_util% (Threshold: $CPU_THRESHOLD%)"
  fi
  
  if [ "$(echo "$disk_util > $DISK_THRESHOLD" | awk '{if ($1) print 1; else print 0}')" -eq 1 ]; then
    subject="High Disk Utilization on $instance_id"
    message="Instance $instance_id has disk utilization of $disk_util%, exceeding the threshold of $DISK_THRESHOLD%."
    send_sns_alert "$subject" "$message"
    send_slack_alert "⚠️ High Disk Utilization: Instance $instance_id has disk utilization of $disk_util% (Threshold: $DISK_THRESHOLD%)"
  fi
  
  if [ "$(echo "$latency > $LATENCY_THRESHOLD" | awk '{if ($1) print 1; else print 0}')" -eq 1 ]; then
    subject="High Network Latency on $instance_id"
    message="Instance $instance_id has network latency of $latency ms, exceeding the threshold of $LATENCY_THRESHOLD ms."
    send_sns_alert "$subject" "$message"
    send_slack_alert "⚠️ High Network Latency: Instance $instance_id has network latency of $latency ms (Threshold: $LATENCY_THRESHOLD ms)"
  fi
}

# Iterate over all instances and monitor each
for instance_id in "${INSTANCE_IDS[@]}"; do
  monitor_instance $instance_id
done

