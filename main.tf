# creating VPC
resource "aws_vpc" "proj_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "proj_vpc"
  }
}

# create public subnets
resource "aws_subnet" "pub_sbn1" {
  vpc_id     = aws_vpc.proj_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "pub_sbn1"
  }
}

resource "aws_subnet" "pub_sbn2" {
  vpc_id     = aws_vpc.proj_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "pub_sbn2"
  }
}

# create private subnets
resource "aws_subnet" "priv_sbn1" {
  vpc_id     = aws_vpc.proj_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "priv_sbn1"
  }
}

resource "aws_subnet" "priv_sbn2" {
  vpc_id     = aws_vpc.proj_vpc.id
  cidr_block = "10.0.4.0/24"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "priv_sbn2"
  }
}

# create Internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.proj_vpc.id

  tags = {
    Name = "igw"
  }
}

# create eip
resource "aws_eip" "proj_eip" {
  domain = "vpc"
  tags = {
    Name = "proj_eip"
  }
}

# create NAT Gateway
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.proj_eip.id
  subnet_id     = aws_subnet.pub_sbn1.id
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "nat_gw"
  }
}

# create public route-table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.proj_vpc.id

route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "public_rt"
  }
}

# create private route-table
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.proj_vpc.id

 route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "private_rt"
  }
}


# create public route-table association
resource "aws_route_table_association" "public_rt_assc" {
  subnet_id      = aws_subnet.pub_sbn1.id
  route_table_id = aws_route_table.public_rt.id
}

# create private route-table association
resource "aws_route_table_association" "priv_rt_assc" {
  subnet_id      = aws_subnet.priv_sbn1.id
  route_table_id = aws_route_table.private_rt.id
}

# create security group frontend
resource "aws_security_group" "web-sg-fe" {
  name        = "web-sg-fe"
  description = "Security group for web server"
  vpc_id      = aws_vpc.proj_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg-fe"
  }
}

# create security group backend
resource "aws_security_group" "sg_backend" {
  name        = "sg_backend"
  description = "database backend-sg"
  vpc_id      = aws_vpc.proj_vpc.id

  ingress {
    description = "MySQL-Aurora from frontend-sg"
    protocol  = "tcp"
    from_port = 3306
    to_port   = 3306
    security_groups = [aws_security_group.web-sg-fe.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg_backend"
  }
}

# create Keypair
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits = 4096
}

# create private key
resource "local_file" "key" {
 content = tls_private_key.key.private_key_pem
 filename = "proj-key"
 file_permission = "400"
}

# create public jey
resource "aws_key_pair" "key" {
  key_name = "proj-pub-key"
  public_key = tls_private_key.key.public_key_openssh
}