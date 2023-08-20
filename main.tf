provider "aws" {
  region  = "us-east-1"
}
variable "subnet_prefix" {
  description = "cidr block for the subnet"
# default = < terraform will give the variable a value if the user doesn't specify one >
default = "10.0.100.0/24"
type = any
}
variable "access_key" {
  description = "AWS access key"
  type = string
}
variable "secret_key" {
  description = "AWS secret_key"
  type = string
}
# 1.create a vpc
resource "aws_vpc" "prod-vpc" {
  cidr_block       = "10.0.0.0/16"

  tags = {
    Name = "prod"
  }
}

# 2. create igw
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id

  tags = {
    Name = "main"
  }
}

# 3. create a route table
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod"
  }
}

# 4. create a subnet
resource "aws_subnet" "sb-1" {
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = var.subnet_prefix[0].cidr_block
  availability_zone = "us-east-1a"
  tags = {
    name = var.subnet_prefix[0].name
    }
}

resource "aws_subnet" "sb-2" {
  vpc_id = aws_vpc.prod-vpc.id
  cidr_block = var.subnet_prefix[1].cidr_block
  availability_zone = "us-east-1a"
  tags = {
    name = var.subnet_prefix[1].name
    }
}


# 5. route table association < associate the subnet to the route table >
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.sb-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# 6. create a security group
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow_web_traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "ssh"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7.  create a network interface 
resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.sb-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

# 8. create a Elastic IP for the network interface in order to connect to it < depends in igw > 
resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}
# output "server_public_ip" {
#   value = aws_eip.one.public_ip
# }
# 9. create a EC2 instance 
resource "aws_instance" "web_server_instance" {
  ami = "ami-022e1a32d3f742bd8"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "main-key"

# 10. Attach the instance to the network interface 
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }
# 11. user data that the instance will be able to run commands once you create it
  user_data = <<-EOF
       #!/bin/bash
        sudo -i
        yum update
        yum install httpd -y
        systemctl start httpd
        bash -c 'echo "your very first web server" > /var/www/html/index.html'
        EOF
    tags = {
      name = "web-server"
    }
}

# output "server_private_IP" {
#   value = aws_instance.web_server_instance.private_ip
# }
# output "server_ID" {
#   value = aws_instance.web_server_instance.id
# }
