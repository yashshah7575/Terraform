provider "aws" {
    access_key = "AKIA6QKRCMW5MSBADLC2"
    secret_key =  "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"
    region =  "us-east-1"
}

# 1.  Create VPC  
resource "aws_vpc" "BoA_VPC" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "BoA_VPC"
  }
}

# 2. Steup  Internet Gateway(Connect EC2  & Internet)
resource "aws_internet_gateway" "BoA_IG" {
  vpc_id = aws_vpc.BoA_VPC.id
  tags = {
    Name = "BoA_IG"
  }
}

# 3. Grant the VPC internet access on its main route table
resource "aws_route" "BoA_ROUTE" {
  route_table_id         = aws_vpc.BoA_VPC.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.BoA_IG.id
}

# Create a subnet to launch our instances into
resource "aws_subnet" "BoA_SUBNET" {
  vpc_id                  = aws_vpc.BoA_VPC.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# 4. A security group for the ELB so it is accessible via the web
resource "aws_security_group" "BoA_SECURITY_GROUP_ELB" {
  name        = "BoA_SECURITY_GROUP_ELB"
  vpc_id      = aws_vpc.BoA_VPC.id

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 5. Our default security group to access the instances over SSH and HTTP
resource "aws_security_group" "BoA_SECURITY_GROUP" {
  name        = "BoA_SECURITY_GROUP"
  vpc_id      = aws_vpc.BoA_VPC.id

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elb" "BoA_ELB" {
  name = "BoELB"
  subnets         = [aws_subnet.BoA_SUBNET.id]
  security_groups = [aws_security_group.BoA_SECURITY_GROUP.id]
  instances       = [aws_instance.BoA_INSTANCE.id]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
}

resource "aws_instance" "BoA_INSTANCE" {
  instance_type = "t2.micro"
  ami = "ami-0c94855ba95c71c99"

  # Our Security group to allow HTTP and SSH access
  vpc_security_group_ids = [aws_security_group.BoA_SECURITY_GROUP.id]

  # We're going to launch into the same subnet as our ELB. In a production
  # environment it's more common to have a separate private subnet for
  # backend instances.
  subnet_id = aws_subnet.BoA_SUBNET.id

  # We run a remote provisioner on the instance after creating it.
  # In this case, we just install nginx and start it. By default,
  # this should be on port 80
  provisioner "remote-exec" {
    inline = [
     "export PATH=$PATH:/usr/bin",
      # install nginx
      "sudo apt-get update",
      "sudo apt-get -y install nginx"    ]
       connection {
        type     = "ssh"
        host     = self.public_ip
        user     = "cloud_user"
        password = "&1Ysumwbmj"
    }
  }
}