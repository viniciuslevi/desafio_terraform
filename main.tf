#Define o provedor de recursos como a AWS e a região
provider "aws" {
  region = "us-east-1"
}

# Define uma variável "projeto"
variable "projeto" {
  description = "Nome do projeto"
  type        = string
  default     = "VExpenses"
}

# Define uma variável "candidato"
variable "candidato" {
  description = "Nome do candidato"
  type        = string
  default     = "Vinicius Levi"
}
# Define um recurso de chave privada
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Cria um par de chaves para a instância EC2
resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

# Cria uma VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
    
  tags = {
    Name = "${var.projeto}-${var.candidato}-vpc"
  }
}
# Cria uma subnet
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.projeto}-${var.candidato}-subnet"
  }
}
# Cria um gateway e relaciona com a vpc
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-igw"
  }
}
# Cria uma tabela de roteamento
resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table"
  }
}
# Cria recurso de associação de tabela de roteamento
resource "aws_route_table_association" "main_association" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id
}
# Cria um grupo de segurança e relaciona com a vpc
resource "aws_security_group" "main_sg" {
  name        = "${var.projeto}-${var.candidato}-sg"
  description = "Permitir SSH, HTTP e HTTPS de qualquer lugar e todo o trafego de saida"
  vpc_id      = aws_vpc.main_vpc.id

  # Regras de entrada
  ingress {
    description      = "Allow SSH from anywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"] # Ou substitua por [SEU_IP/32]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description = "Allow HTTP from anywhere, for nginx"
    from_port  = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description = "Allow HTTPS from anywhere"
    from_port  = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  # Regras de saída
  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-sg"
  }
}
# Recupera a imagem mais recente do Debian 12
data "aws_ami" "debian12" {
  most_recent = true

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["679593333241"]
}
# Criação da instância EC2
resource "aws_instance" "debian_ec2" {
  ami             = data.aws_ami.debian12.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.main_subnet.id
  key_name        = aws_key_pair.ec2_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.main_sg.id]

  associate_public_ip_address = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = true
  }
  # Script de inicialização da instancia
  user_data = <<-EOF
              #!/bin/bash

              # Configuração não-interativa para apt
              export DEBIAN_FRONTEND=noninteractive

              # Atualizar sistema sem prompts
              apt-get update -y
              apt-get upgrade -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef"

              # Instalar Nginx e ferramentas de segurança
              apt-get install -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" nginx fail2ban ufw

              # Ajustes de segurança SSH (antes de qualquer atualização que possa modificar o arquivo)
              sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
              sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

              # Configurar o firewall UFW
              ufw default deny incominguf
              ufw default allow outgoing
              ufw allow ssh
              ufw allow 80/tcp
              ufw allow 443/tcp
              ufw --force enabled
              
              # Configurar página padrão do Nginx
              cat > /var/www/html/index.nginx-debian.html<<HTML
              <!DOCTYPE html>
              <html>
              <head>
                <title>VExpenses Demo</title>
                <style>
                  body {
                    font-family: Arial, sans-serif;
                    margin: 40px;
                    color: #333;
                  }
                  h1 {
                    color: #0066cc;
                  }
                </style>
              </head>
              <body>
                <h1>VExpenses Challenge Completed!</h1>
                <p>Terraform Infrastructure Deployment Successful</p>
                <p>Implemented by: ${var.candidato}</p>
              </body>
              </html>
              HTML
              
              # Configurar fail2ban para proteção SSH
              cat > /etc/fail2ban/jail.local <<FAIL2BAN
              [sshd]
              enabled = true
              port = ssh
              filter = sshd
              logpath = /var/log/auth.log
              maxretry = 5
              bantime = 3600
              FAIL2BAN
              
              # Habilitar e iniciar Nginx
              systemctl enable nginx
              systemctl start nginx
              
              # Reiniciar fail2ban e SSH              
              systemctl restart fail2ban
              systemctl restart ssh
              EOF

  tags = {
    Name = "${var.projeto}-${var.candidato}-ec2"
    Service = "nginx"
  }
}
# retorna a private_key
output "private_key" {
  description = "Chave privada para acessar a instância EC2"
  value       = tls_private_key.ec2_key.private_key_pem
  sensitive   = true
}
# retorna o ip publico da ec2
output "ec2_public_ip" {
  description = "Endereço IP público da instância EC2"
  value       = aws_instance.debian_ec2.public_ip
}
output "nginx_url" {
  description = "URL do servidor Nginx"
  value = "http://${aws_instance.debian_ec2.public_ip}" 
}