
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
}

# Configurazione providers
provider "aws" {
  region  = "eu-central-1"
}

#Inserimento variabile per numero istanze RDS
variable "rds_instance_count" {
    type         = number
    default      = 2
    description  = "Questo parametro definisce il numero di istanze RDS"
}

#Inserimento variabile user_data

data "template_file" "user_data" {
  template = file("install_wordpress.sh")
  vars = {
    DB_NAME     = "Dalterix"
    DB_HOSTNAME = aws_rds_cluster.wordpress-rds-cluster3.endpoint
    DB_USERNAME = "admin"
    DB_PASSWORD = "password"
    LB_HOSTNAME = aws_lb.wordpress_alb.dns_name
  }
}

# Crazione VPC
resource "aws_vpc" "vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name        = "vpc-dalterix"
  }
}

# Creazione internet gateway
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "igw-dalterix"
  }
}

# Creazione 2 subnets pubbliche
resource "aws_subnet" "public_1" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-central-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-central-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-2"
  }
}

# Crazione 2 Subnets private
resource "aws_subnet" "private_1" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "eu-central-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "private-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "eu-central-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "private-2"
  }
}

# Creazione route table per internet gateway
resource "aws_route_table" "dalterix_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }
    tags = {
    Name = "wordpress-rt"
  }
}

# Associazione public subnet alla route table

resource "aws_route_table_association" "public_route_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.dalterix_rt.id
}

resource "aws_route_table_association" "public_route_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.dalterix_rt.id
}

# Creazione security security_groups
resource "aws_security_group" "public_sg" {
  name        = "public-sg"
  description = "Allow web and ssh traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    from_port         = 22
    to_port           = 22
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]

  }
}

resource "aws_security_group" "private_sg" {
  name        = "private-sg"
  description = "Allow web tier and ssh traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port        = 3306
    to_port          = 3306
    protocol         = "tcp"
    cidr_blocks      = ["10.0.0.0/16"]
    security_groups = [ aws_security_group.public_sg.id ]
  }
  ingress {
    from_port         = 22
    to_port           = 22
    protocol          = "tcp"
    cidr_blocks       = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]

  }
}


# Security group per ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "security group for alb"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Creazione ALB
resource "aws_lb" "wordpress_alb" {
  name               = "alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

# Creazione target groups per Load balancer

resource "aws_lb_target_group" "dalterix_tg" {
  name     = "wordpress-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id


  stickiness {
     type            = "lb_cookie"
     cookie_duration = 1800
     enabled         = "true"
   }

   }



# Creazione target attachments
resource "aws_lb_target_group_attachment" "tg_attach1" {
  target_group_arn = aws_lb_target_group.dalterix_tg.arn
  target_id        = aws_instance.web1.id
  port             = 80

  depends_on = [aws_instance.web1]
}

resource "aws_lb_target_group_attachment" "tg_attach2" {
  target_group_arn = aws_lb_target_group.dalterix_tg.arn
  target_id        = aws_instance.web2.id
  port             = 80

  depends_on = [aws_instance.web2]
}

resource "aws_lb_target_group_attachment" "tg_attach3" {
  target_group_arn = aws_lb_target_group.dalterix_tg.arn
  target_id        = aws_instance.web3.id
  port             = 80

  depends_on = [aws_instance.web3]
}

resource "aws_lb_target_group_attachment" "tg_attach4" {
  target_group_arn = aws_lb_target_group.dalterix_tg.arn
  target_id        = aws_instance.web4.id
  port             = 80

  depends_on = [aws_instance.web4]
}

# Creazione listener
resource "aws_lb_listener" "listener_lb" {
  load_balancer_arn = aws_lb.wordpress_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dalterix_tg.arn
  }
}

# Prima istanza EC2
resource "aws_instance" "web1" {
  ami           = "ami-0c956e207f9d113d5"
  instance_type = "t2.micro"
  key_name          = "wordpressha"
  availability_zone = "eu-central-1a"
  vpc_security_group_ids      = [aws_security_group.public_sg.id]
  subnet_id                   = aws_subnet.public_1.id
  associate_public_ip_address = true
  user_data = data.template_file.user_data.rendered
  tags = {
    Name = "web1_instance"
  }
}

resource "aws_security_group" "instance" {
 name = "terraform-example-instance"
 ingress {
 from_port = 80
 to_port = 80
 protocol = "tcp"
 cidr_blocks = ["0.0.0.0/0"]
 }
}



#Seconda istanza EC2

resource "aws_instance" "web2" {
  ami           = "ami-0c956e207f9d113d5"
  instance_type = "t2.micro"
  key_name          = "wordpressha"
  availability_zone = "eu-central-1b"
  vpc_security_group_ids      = [aws_security_group.public_sg.id]
  subnet_id                   = aws_subnet.public_2.id
  associate_public_ip_address = true
  user_data = data.template_file.user_data.rendered

  tags = {
    Name = "web2_instance"
  }
}

#Terza istanza EC2

resource "aws_instance" "web3" {
  ami           = "ami-0c956e207f9d113d5"
  instance_type = "t2.micro"
  key_name          = "wordpressha"
  availability_zone = "eu-central-1a"
  vpc_security_group_ids      = [aws_security_group.public_sg.id]
  subnet_id                   = aws_subnet.public_1.id
  associate_public_ip_address = true
  user_data = data.template_file.user_data.rendered

  tags = {
    Name = "web3_instance"
  }
}

#Quarta istanza EC2
resource "aws_instance" "web4" {
  ami           = "ami-0c956e207f9d113d5"
  instance_type = "t2.micro"
  key_name          = "wordpressha"
  availability_zone = "eu-central-1b"
  vpc_security_group_ids      = [aws_security_group.public_sg.id]
  subnet_id                   = aws_subnet.public_2.id
  associate_public_ip_address = true
  user_data = data.template_file.user_data.rendered
  tags = {
    Name = "web4_instance"
  }
}
# Database subnet group
resource "aws_db_subnet_group" "db_subnet"  {
    name       = "db-subnet"
    subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

#Parametri di definizione del tipo di cluster RDS
resource "aws_rds_cluster" "wordpress-rds-cluster3" {
  cluster_identifier     = "rds-cluster3"
  engine                 = "aurora-mysql"
  engine_version         = "5.7.mysql_aurora.2.07.2"
  availability_zones     = ["eu-central-1a", "eu-central-1b"] #causes every time to destroy and rebuild rds cluster
  database_name          = "Dalterix"
  db_subnet_group_name   = aws_db_subnet_group.db_subnet.name
  master_username        = "admin"
  master_password        = "password"
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  skip_final_snapshot    = true
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

#Istanza RDS
resource "aws_rds_cluster_instance" "wordpress-rds-instances1" {
  count                = 2
  identifier           = "wordpressdata-rds-instance-${count.index}"
  db_subnet_group_name = aws_db_subnet_group.db_subnet.name
  cluster_identifier   = aws_rds_cluster.wordpress-rds-cluster3.id
  instance_class       = "db.r5.large"
  engine               = aws_rds_cluster.wordpress-rds-cluster3.engine
  engine_version       = aws_rds_cluster.wordpress-rds-cluster3.engine_version
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}


#Outputs finali

# Outputs
# Ec2 instance public ipv4 address
output "ec2_public_ip" {
  value = aws_instance.web1.public_ip
}

output "db_hostname" {
  description = "The DNS name of RDS"
  value       = aws_rds_cluster.wordpress-rds-cluster3.endpoint
}

# Getting the DNS of load balancer
output "lb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = "${aws_lb.wordpress_alb.dns_name}"
}
