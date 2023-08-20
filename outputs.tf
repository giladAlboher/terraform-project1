output "server_public_ip" {
  value = aws_eip.one.public_ip
}

output "server_private_IP" {
  value = aws_instance.web_server_instance.private_ip
}

output "server_ID" {
  value = aws_instance.web_server_instance.id
}
