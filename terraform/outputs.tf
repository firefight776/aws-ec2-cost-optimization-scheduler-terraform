output "lambda_function_name" {
  value = aws_lambda_function.scheduler.function_name
}

output "start_schedule_name" {
  value = var.enable_scheduler ? aws_scheduler_schedule.start_schedule[0].name : null
}

output "stop_schedule_name" {
  value = var.enable_scheduler ? aws_scheduler_schedule.stop_schedule[0].name : null
}