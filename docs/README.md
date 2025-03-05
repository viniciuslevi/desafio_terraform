# Desafio - Estágio em DevOps

O presente documento é uma resposta ao desafio de Estágio em DevOps. Ele contém uma análise detalhada e técnica do código fornecido, abordando os recursos implementados e suas funcionalidade no código main.tf fornecido, além de apresentar e comentar as modificações realizadas no arquivo. Ao longo do documento estão presentes links que levam a informações mais detalhadas nas documentações em relação as ferramentas ou termos utilizados.

O arquivo modificado está na raiz do diretório como [main.tf](https://github.com/viniciuslevi/desafio_terraform/tree/main/src/main.tf), para executá-lo, basta seguir as orientações contidas no tópico 4 deste mesmo readme.md. Enquanto o [arquivo original](https://github.com/viniciuslevi/desafio_terraform/blob/main/docs/original-main.tf) está dentro do diretório docs.

## Contextualização:
[Terraform](https://developer.hashicorp.com/terraform/intro) é uma ferramenta de software de *Infraestructure as Code* (IaC) designada para automatizar a criação e manutenção de infraestrutura cloud, que se utiliza da linguagem declarativa HCL (HashiCorp Configuration Language) (ou JSON, opcionalmente).

A ferramenta também contém recursos que permite armazenar estados de componentes de infraestrutura, bem como mapear o código escrito, avaliar as mudanças e informar para o usuário, quais modificações serão realizadas na infraestrutura do projeto a partir da execução do código. 

## 1. Análise Técnica do Código Terraform

### 1.1 - [Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
```tf
provider "aws" {
  region = "us-east-1"
}
```

Define o provedor de recursos de recursos e a região de operação. Com o provedor de recursos definido, o Terraform se encarrega de baixar as dependências relacionadas.

Para usar a AWS, é necessário configurar previamente as credencias de acesso pelo AWS CLI. O Terraform pode usar as credenciais armazenadas do AWS CLI para executar o código.

### 1.2 - Variable
```tf
variable "projeto" {
  description = "Nome do projeto"
  type        = string
  default     = "VExpenses"
}

variable "candidato" {
  description = "Nome do candidato"
  type        = string
  default     = "SeuNome"
}
```
Os dois blocos criam duas variáveis cada: "projeto" e "candidato". Em ambas, são incluidas também os atributos: description (descrição), type (tipo) e default (nome).

### 1.3 - EC2-key
```tf
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}
```

O primeiro bloco define uma chave privada usando o algoritmo _RSA_ e o tamanho da mesma.

O segundo bloco cria um par de chaves na _AWS_ para uso em instâncias _EC2_. Também atribui o nome como a concatenação dos nomes do projeto e candidato e define a chave pública do par atribuindo o recurso _public_key_openssh_.

### 1.4 - VPC
```tf
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.projeto}-${var.candidato}-vpc"
  }
}
```

Define uma [VPC](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) (Virtual Private Cloud), uma rede virtual isolada na AWS, com [CIDR](https://aws.amazon.com/pt/what-is/cidr/) (Encaminhamento Entre Domínios Sem Classificação) 10.0.0.0/16. Ou seja, com os primeiros 16 bits (10.0) sendo o endereço da rede.

### 1.5 - Subnet
```tf
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.projeto}-${var.candidato}-subnet"
  }
}
```
Cria uma [Subnet](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet), que estará dentro da VPC criada no trecho 4, vinculada pelo _vpc_id_. O endereço da subnet é 10.0.1 (24 bits), definido no _cidr_block_ e a zona é configurada para "us-east-1a".

### 1.6 - Gateway
```tf
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-igw"
  }
}
```
Cria o recurso [Gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway), responsável por permitir que instâncias da VPC se liguem a internet.
Internet Gateway é o _destino_ para o tráfego que precisa sair para a internet.

### 1.7 - Route Table:
```tf
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

resource "aws_route_table_association" "main_association" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table_association"
  }
}
```
O primeiro bloco cria o recurso de tabela de roteamento, que servirá para fornecer direcionar para onde o trafego de saída da VPC deverá ser direcionado. No caso, o trafego dos endereços especificados em _cidr_block_(0.0.0.0/0) será encaminhado para o Gateway, pelo _gateway_id_.

O segundo bloco permite especificar qual tabela de roteamento deve ser usada para rotear o tráfego da sub-rede. No código, é vinculada a subnet, a mesma tabela da VPC.

### 1.8 - Security Group
```tf
resource "aws_security_group" "main_sg" {
  name        = "${var.projeto}-${var.candidato}-sg"
  description = "Permitir SSH de qualquer lugar e todo o tráfego de saída"
  vpc_id      = aws_vpc.main_vpc.id

  # Regras de entrada
  ingress {
    description      = "Allow SSH from anywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
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
```
O bloco em questão cria um Security Group, e vincula a VPC criada anteriormente. Em seguida, inclui ao grupo regras de restrição de entrada e saída. 

A primeira regra "ingress" permite entrada de qualquer IP à porta 22, que é usada pelo serviço de SSH. Já a segunda, permite saída do tráfego para qualquer IP em todas as portas e todos os protocolos.

### 1.9 - AMI
```tf
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
```
Cria uma imagem usando o recruso _aws_ami_ (Amazon Machine Image), configurando-a para debian na versão 12.

### 1.10 - Instância EC2
```tf
resource "aws_instance" "debian_ec2" {
  ami             = data.aws_ami.debian12.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.main_subnet.id
  key_name        = aws_key_pair.ec2_key_pair.key_name
  security_groups = [aws_security_group.main_sg.name]

  associate_public_ip_address = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get upgrade -y
              EOF

  tags = {
    Name = "${var.projeto}-${var.candidato}-ec2"
  }
}
```
Cria uma instância EC2, definindo atributos como a imagem a ser utilizada (debian12 criada anteriormente), o tipo da instância (em termos de poder computacional), a subnet a qual a instância pertencerá, o par de chaves de acesso e o grupo de segurança que restringirá o acesso à máquina.

Também associa um ip público, define o volume e tipo do armazenamento e se deve apaga-lo quando a maquina for encerrada.

No user_data contém o script que irá rodar assim que o processo de criação da máquina for finalizado. O Script que é lançado com o Shebang especificando o interpretador bash, é seguido por comandos para atualizar o S.O.

### 1.11 - Outputs
```tf
output "private_key" {
  description = "Chave privada para acessar a instância EC2"
  value       = tls_private_key.ec2_key.private_key_pem
  sensitive   = true
}

output "ec2_public_ip" {
  description = "Endereço IP público da instância EC2"
  value       = aws_instance.debian_ec2.public_ip
}

```
Os dois blocos produzem logs no terminal, ao rodar _terraform apply_. O primeiro se trata da chave privada de acesso SSH a máquina EC2 criada, a segunda imprime o IP público.

### 1.12 - Observações
Alguns trechos do código tinham alguns erros de sintaxe, detectado pela ferramenta (terraform).
#### Trecho 7 (1.7) - Bloco 1:
```tf
resource "aws_route_table_association" "main_association" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id

  tags = {
    Name = "${var.projeto}-${var.candidato}-route_table_association"
  }
}
```
Pela [documentação](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association), o recurso _aws_route_table_ não possui o argumento **_tags_**. No arquivo modificado, o argumento foi retirado.

#### Trecho 10 (1.10):
```tf
resource "aws_instance" "debian_ec2" {
  ami             = data.aws_ami.debian12.id
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.main_subnet.id
  key_name        = aws_key_pair.ec2_key_pair.key_name
  security_groups = [aws_security_group.main_sg.name]

  associate_public_ip_address = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get upgrade -y
              EOF

  tags = {
    Name = "${var.projeto}-${var.candidato}-ec2"
  }
}
```
Pela [documentação](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance), se as instâncias estão dentro de uma VPC, deve-se usar o argumento [`vpc_security_group_ids`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance#vpc_security_group_ids-1) ao invés de [`security_groups`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance#security_groups-1).



## 2. Modificações e Melhorias do Código Terraform
As modificações destacadas a seguir, foram todas incluídas no documento modificado [main.tf](https://github.com/viniciuslevi/desafio_terraform/tree/main/src/main.tf). A forma como estão apresentadas aqui não é exatamente como está no main.tf, porque aqui prioriza-se a apresentação de cada modificação realizada. Entretanto, todas as configurações são identicas.

### 2.1 - Aplicação de melhorias de segurança

Uma prática interessante com relação a conexão via SSH, seria restringir o acesso a EC2 para apenas para a sua máquina, configurando no CIDR do recurso Security Group, o seu IP público.

```tf
 ingress {
    description      = "Allow SSH from anywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["SEU_IP/0"]
  }
  ```
  Assim, conexão de nenhuma outra origem será aceita. 
  
  Para descobrir o IP público, execute:
  ```bash
  curl ifconfig.me
  ```


Uma outra alteração no código com relação a EC2 para segurança podem ser implementadas no _user_data_: 

- Instalar e configurar **_fail2ban_** para proteção SSH pode previnir ataques bem sucedidos via força bruta. A ferramenta monitora logs em tempo real do sistema e toma medidas de prevenção contra IPs identificados como suspeitos.
```tf
sudo apt-get fail2ben

cat > /etc/fail2ban/jail.local <<FAIL2BAN 
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
FAIL2BAN

chmod 644 /etc/fail2ban/jail.local
systemctl restart fail2ban
```

- Apesar do grupo de segurança já restringir acesso a portas da VM, instalar ferramentas de firewall a nível de EC2 podem ainda prevenir que mesmo que uma configuração do grupo de segurança seja alterada, a máquina ainda seguirá com as restrições do **_ufw_**;
```tf
sudo apt-get ufw

ufw default deny incominguf
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
```

- Como a maioria dos ataques ocorrem usando o usuário root, é interessante remover o login do user root via SSH.
```tf
sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config 
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

systemctl restart ssh
```

### 2.2 - Automação da Instalação do Nginx
#### Alteração 1:
```tf
resource "aws_security_group" "main_sg" {
  name        = "${var.projeto}-${var.candidato}-sg"
  description = "Permitir SSH, HTTP e HTTPS de qualquer lugar e todo o trafego de saida"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    description      = "Allow SSH from anywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
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
```
Foi implementado mais duas regras de acesso ao security group. A regra descrita como "Allow HTTP from anywhere, for nginx", permitirá requisições HTTP a porta 80 por qualquer IP.

#### Alteração 2:
```tf
# [...] código acima
  user_data = <<-EOF
              #!/bin/bash
              export DEBIAN_FRONTEND=noninteractive
              apt-get update -y
              apt-get upgrade -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef"
              apt-get install -y -o Dpkg::Options::="--force-confold" -o Dpkg::Options::="--force-confdef" nginx
              cat > /var/www/html/index.nginx-debian.html<<HTML
              <!DOCTYPE html>
              <html>
              <head>
                <title>VExpenses Demo</title>
                <style>
                  body { font-family: Arial, sans-serif; margin: 40px; color: #333; }
                  h1 { color: #0066cc; }
                </style>
              </head>
              <body>
                <h1>VExpenses Challenge Completed!</h1>
                <p>Terraform Infrastructure Deployment Successful</p>
                <p>Implemented by: ${var.candidato}</p>
              </body>
              </html>
              HTML
              systemctl start nginx
              systemctl enable nginx
              echo "User data script completed"
              EOF

# [...] mais código abaixo

```
A segunda e mais significativa alteração é em relação ao _`user_data`_, que agora inclui também no seu script, a instalação da ferramenta nginx, seguido por comandos que ativam o serviço. O conteúdo do HTML padrão do nginx também é alterado, somente pra título de visualização.

Vale ressaltar que flags do DPKG e configurações de terminal não interativo foram adicionados, pois no momento em que testava o código, identifiquei que as demais tarefas do script abaixo dos comandos de atualização não estavam sendo realizadas pelo terminal  estar aguardando uma confirmação mesmo com a flag -y aplicada a apt-get update e apt-get upgrade.

#### Alteração 3:
```tf
output "nginx_url" {
  description = "URL do servidor Nginx"
  value = "http://${aws_instance.debian_ec2.public_ip}"
}
```
Ao rodar com _terraform apply_, além da private_key e do IP é impresso o link para acesso.



### Outras alterações

Uma outra modificação implementada, mas que interfere apenas na organização do código é a separação do script contido em _user_data_ em outro arquivo, denominado _userdata.sh_. O arquivo é então chamado no bloco de recurso do EC2 e carregado no momento da execução.

```tf
  # Script de inicialização da instancia
  user_data = templatefile("./userdata.sh", { 
    candidato = var.candidato
  })
```
É uma boa prática separar o arquivo terraform em varios outros: variaveis.tf, outputs.tf e etc. Mas como não tivemos muitos destes componentes, optei por deixa-los todos num único arquivo e separar somente o script do _user_data_.

## 3. Instruções de Uso

### Guia de Implantação de Infraestrutura AWS com Terraform

Este guia fornece instruções passo a passo para implantar o projeto de infraestrutura VExpenses usando Terraform a partir do GitHub.

#### Pré-requisitos

- [Git](vscode-file://vscode-app/usr/share/code/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html) (para clonar o repositório)
- [Terraform](vscode-file://vscode-app/usr/share/code/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html) (v1.0.0 ou mais recente)
- [Conta AWS](vscode-file://vscode-app/usr/share/code/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html)
- [AWS CLI](vscode-file://vscode-app/usr/share/code/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html) (recomendado para gerenciamento de credenciais)

#### 1. Clone o Repositório
```bash
git clone https://github.com/username/desafioTerraform.git
cd desafioTerraform/src
```
#### 2. Configure as Credenciais AWS

Configure suas credenciais AWS usando um destes métodos:

##### Opção A: Configuração AWS CLI (Recomendado)
```bash
aws configure
```
Digite seu ID de Chave de Acesso, Chave de Acesso Secreta, Região (us-east-1) e formato de saída quando solicitado.

##### Opção B: Variáveis de Ambiente
```bash
export AWS_ACCESS_KEY_ID="sua_chave_de_acesso"
export AWS_SECRET_ACCESS_KEY="sua_chave_secreta"
export AWS_REGION="us-east-1"
```
#### 3. Personalize as Variáveis (Opcional)

Edite as variáveis no arquivo [main.tf](vscode-file://vscode-app/usr/share/code/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html) para alterar o nome do projeto ou seu nome:
```bash
# Edite usando qualquer editor de texto
nano main.tf
```

Procure estas linhas e modifique conforme necessário:
```tf
variable "projeto" {
  description = "Nome do projeto"
  type        = string
  default     = "VExpenses"  # Altere este valor se desejar
}

variable "candidato" {
  description = "Nome do candidato"
  type        = string
  default     = "Vinicius Levi"   # Altere para seu nome
}
```
#### 4. Assine a AMI Debian 12

Assine a AMI do Debian 12 no AWS Marketplace:

1. Visite: [https://aws.amazon.com/marketplace/pp?sku=5ctsrtfjsovfs7giesa0alwtp](vscode-file://vscode-app/usr/share/code/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html)
2. Clique em "Continue to Subscribe"
3. Aceite os termos e condições

#### 5. Inicialize o Terraform
```bash
terraform init
```
#### 6. Valide a Configuração
```bash
terraform validate
```
#### 7. Revise o Plano de Execução
```bash
terraform plan
```
#### 8. Implante a Infraestrutura
```bash
terraform apply
```
Digite `yes` quando solicitado para confirmar a implantação.

#### 9. Acesse seus Recursos

Após a implantação bem-sucedida, o Terraform exibirá:

- Endereço IP público da instância EC2
- URL para acessar o servidor Nginx
- Chave privada para acesso SSH (sensível)

##### Salve a Chave Privada para Acesso SSH
```bash
terraform output -raw private_key > key.pem
chmod 400 key.pem
```
##### Acesse sua Instância via SSH
```bash
ssh -i key.pem admin@$(terraform output -raw ec2_public_ip)
```
##### Acesse o Servidor Web Nginx

Abra esta URL no seu navegador:
```bash
terraform output nginx_url
```
#### 10. Solução de Problemas

#### Se o Nginx não estiver funcionando:

Acesse a instância via SSH e verifique:
```bash
sudo systemctl status nginx
sudo cat /var/log/cloud-init-output.log
```
##### Tente instalar o Nginx manualmente:
```bash
sudo apt update
sudo apt install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx
```
#### 11. Limpe os Recursos

Quando terminar, destrua a infraestrutura para evitar cobranças contínuas:
```bash
terraform destroy
```
Digite `yes` quando solicitado para confirmar.

#### 12. Estrutura do Repositório

- [main.tf](vscode-file://vscode-app/usr/share/code/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html) - Arquivo principal de configuração do Terraform
- [terraform.tfstate](vscode-file://vscode-app/usr/share/code/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html) - Arquivo de estado (criado após aplicação)
- [terraform.tfstate.backup](vscode-file://vscode-app/usr/share/code/resources/app/out/vs/code/electron-sandbox/workbench/workbench.html) - Backup do estado anterior

#### Nota de Segurança

Lembre-se de nunca enviar credenciais AWS ou chaves privadas para o GitHub. O arquivo `.gitignore` deve excluir arquivos `.pem` e `.tfstate`.