module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "Production-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-north-1a"]
  private_subnets = ["10.0.1.0/24"]
  #azs             = ["eu-north-1a", "eu-north-1b"]
  #private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24"]

  tags = {
    Terraform = "true"
    Environment = "prod"
  }
}

# Security group for the web server
resource "aws_security_group" "web_server_sg" {
  name = "Public Web Server Security group"
  description = "A security group for the public web server"
  vpc_id = module.vpc.default_vpc_id#!
  tags = {
    Name = "Public Web Server Security group"
  }
}

# Retrieve my own IP
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

# Create a local value for the cidr block
locals {
  my_public_ip_block = "${chomp(data.http.my_ip.body)}/32"
}

# Accept inbound http requests from all IPs
resource "aws_vpc_security_group_ingress_rule" "allow_http_in" {
  security_group_id = aws_security_group.web_server_sg.id
  from_port = 80
  to_port = 80
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

# Accept outbound http requests to all IPs
resource "aws_vpc_security_group_egress_rule" "allow_http_out" {
  security_group_id = aws_security_group.web_server_sg.id
  from_port = 80
  to_port = 80
  ip_protocol = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}

# Accept inbound ssh requests only from the IP of the creater
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_in" {
  security_group_id = aws_security_group.web_server_sg.id
  from_port = 22
  to_port = 22
  ip_protocol = "tcp"
  cidr_ipv4 = local.my_public_ip_block
}

# Security group for the database server
resource "aws_security_group" "db_sg" {
  name = "Aurora Database Security Group"
  description = "Security group for the Aurora Database"
  vpc_id = module.vpc.default_vpc_id#!
  tags = {
    Name = "Aurora Database Security Group"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_sql_in" {
  security_group_id = aws_security_group.db_sg.id
  ip_protocol = "tcp"
  from_port = 5432
  to_port = 5432
  referenced_security_group_id = aws_security_group.web_server_sg.id
}

resource "aws_vpc_security_group_egress_rule" "allow_sql_out" {
  security_group_id = aws_security_group.db_sg.id
  ip_protocol = "tcp"
  from_port = 5432
  to_port = 5432
  referenced_security_group_id = aws_security_group.web_server_sg.id
}

resource "aws_instance" "web" {
  ami                         = var.ami
  instance_type               = "t3.micro"
  associate_public_ip_address = true
  # Provide the first public subent to the instance
  subnet_id = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.web_server_sg.id]
  tags = {
    Name = "Public Web Server"
  }
}

# Subnet group
resource "aws_db_subnet_group" "sgroup" {
  name = "main-subnet-group"
  # provide the list of all private subnets that will be in a group
  subnet_ids = module.vpc.private_subnets
  tags = {
    Name  = "Subnet Group"
  }
}

# Aurora Database Cluster
resource "aws_rds_cluster" "prod_db" {
  engine = "aurora-mysql"
  engine_version = "3.08.2.mysql_aurora.8.0.39"
  cluster_identifier = "production-db-cluster"
  database_name = "prod_db"
  master_username = "admin"
  master_password = "admin123"
  vpc_security_group_ids = [aws_security_group.db_sg.id]

}

# Aurora Database Instance
resource "aws_rds_cluster_instance" "prod_db_instance" {
  cluster_identifier = aws_rds_cluster.prod_db.id
  engine = aws_rds_cluster.prod_db.engine
  instance_class = "db.t3.medium"
  engine_version = aws_rds_cluster.prod_db.engine_version
  identifier = "production-db-write"
}