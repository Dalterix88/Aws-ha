
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
    Name = "project-rt"
  }
}

# Associazione public subnet alla route table
resource "aws_route_table_association" "public_route_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.project_rt.id
}

resource "aws_route_table_association" "public_route_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.project_rt.id
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
resource "aws_lb" "project_alb" {
  name               = "alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

# Creazione target groups ALB
resource "aws_lb_target_group" "dalterix_tg" {
  name     = "project-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  depends_on = [aws_vpc.vpc]
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

  depends_on = [aws_instance.web1]
}

resource "aws_lb_target_group_attachment" "tg_attach4" {
  target_group_arn = aws_lb_target_group.dalterix_tg.arn
  target_id        = aws_instance.web4.id
  port             = 80

  depends_on = [aws_instance.web1]
}

# Creazione listener
resource "aws_lb_listener" "listener_lb" {
  load_balancer_arn = aws_lb.project_alb.arn
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
  user_data = <<-EOF
        #!/bin/bash
        yum update -y
        yum install httpd -y
        systemctl start httpd
        systemctl enable httpd
        echo "<html><body><h1>Hi there</h1></body></html>" > /var/www/html/index.html
        sudo yum install -y amazon-linux-extras
        sudo amazon-linux-extras enable php7.4
        sudo yum clean metadata
        sudo yum install -y  php php-{pear,cgi,common,curl,mbstring,gd,mysqlnd,gettext,bcmath,json,xml,fpm,intl,zip,imap}
        sudo service httpd restart
        sudo chmod go+rw /var/www/html
        cd /var/www/html
        wget http://wordpress.org/latest.tar.gz
        tar -xzvf latest.tar.gz
        sudo chown -R apache /var/www
        sudo chgrp -R apache /var/www
        sudo chmod -R 777 /var/www/html/wordpress/
        sudo service httpd restart
        EOF

  tags = {
    Name = "web1_instance"
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
  user_data = <<-EOF
        #!/bin/bash
        yum update -y
        yum install httpd -y
        systemctl start httpd
        systemctl enable httpd
        echo "<html><body><h1>Hi there again</h1></body></html>" > /var/www/html/index.html
        sudo yum install -y amazon-linux-extras
        sudo amazon-linux-extras enable php7.4
        sudo yum clean metadata
        sudo yum install -y  php php-{pear,cgi,common,curl,mbstring,gd,mysqlnd,gettext,bcmath,json,xml,fpm,intl,zip,imap}
        sudo service httpd restart
        sudo chmod go+rw /var/www/html
        cd /var/www/html
        wget http://wordpress.org/latest.tar.gz
        tar -xzvf latest.tar.gz
        sudo chown -R apache /var/www
        sudo chgrp -R apache /var/www
        sudo chmod -R 777 /var/www/html/wordpress/
        sudo service httpd restart
        EOF

  tags = {
    Name = "web2_instance"
  }
}

#Terza istanza

resource "aws_instance" "web3" {
  ami           = "ami-0c956e207f9d113d5"
  instance_type = "t2.micro"
  key_name          = "wordpressha"
  availability_zone = "eu-central-1a"
  vpc_security_group_ids      = [aws_security_group.public_sg.id]
  subnet_id                   = aws_subnet.public_1.id
  associate_public_ip_address = true
  user_data = <<-EOF
        #!/bin/bash
        yum update -y
        yum install httpd -y
        systemctl start httpd
        systemctl enable httpd
        echo "<html><body><h1>Hi there</h1></body></html>" > /var/www/html/index.html
        sudo yum install -y amazon-linux-extras
        sudo amazon-linux-extras enable php7.4
        sudo yum clean metadata
        sudo yum install -y  php php-{pear,cgi,common,curl,mbstring,gd,mysqlnd,gettext,bcmath,json,xml,fpm,intl,zip,imap}
        sudo service httpd restart
        sudo chmod go+rw /var/www/html
        cd /var/www/html
        wget http://wordpress.org/latest.tar.gz
        tar -xzvf latest.tar.gz
        sudo chown -R apache /var/www
        sudo chgrp -R apache /var/www
        sudo chmod -R 777 /var/www/html/wordpress/
        sudo service httpd restart
        EOF

  tags = {
    Name = "web3_instance"
  }
}

#Quarta istanza

resource "aws_instance" "web4" {
  ami           = "ami-0c956e207f9d113d5"
  instance_type = "t2.micro"
  key_name          = "wordpressha"
  availability_zone = "eu-central-1b"
  vpc_security_group_ids      = [aws_security_group.public_sg.id]
  subnet_id                   = aws_subnet.public_2.id
  associate_public_ip_address = true
  user_data = <<-EOF
        #!/bin/bash
        yum update -y
        yum install httpd -y
        systemctl start httpd
        systemctl enable httpd
        echo "<html><body><h1>Hi there again</h1></body></html>" > /var/www/html/index.html
        sudo yum install -y amazon-linux-extras
        sudo amazon-linux-extras enable php7.4
        sudo yum clean metadata
        sudo yum install -y  php php-{pear,cgi,common,curl,mbstring,gd,mysqlnd,gettext,bcmath,json,xml,fpm,intl,zip,imap}
        sudo service httpd restart
        sudo chmod go+rw /var/www/html
        cd /var/www/html
        wget http://wordpress.org/latest.tar.gz
        tar -xzvf latest.tar.gz
        sudo chown -R apache /var/www
        sudo chgrp -R apache /var/www
        sudo chmod -R 777 /var/www/html/wordpress/
        sudo service httpd restart
        EOF

  tags = {
    Name = "web4_instance"
  }
}

# Database subnet group
resource "aws_db_subnet_group" "db_subnet"  {
    name       = "db-subnet"
    subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

# Creazione istanza RDS
resource "aws_db_instance" "project_db" {
  allocated_storage    = 5
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  identifier           = "db-instance"
  db_name              = "Dalterix"
  username             = "admin"
  password             = "password"
  db_subnet_group_name = aws_db_subnet_group.db_subnet.id
  vpc_security_group_ids = [aws_security_group.private_sg.id]
  publicly_accessible = false
  skip_final_snapshot  = true
}

#Outputs finali

# Outputs
# Ec2 instance public ipv4 address
output "ec2_public_ip" {
  value = aws_instance.web1.public_ip
}

# Db instance address
output "db_instance_address" {
    value = aws_db_instance.project_db.address
}

# Getting the DNS of load balancer
output "lb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = "${aws_lb.project_alb.dns_name}"
}
