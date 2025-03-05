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
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

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
  <p>Implemented by: ${candidato}</p>
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