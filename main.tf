###############################################################
###############################################################
############   Terraform basic template for AWS    ############
##############           by D.Popov              ##############
###############################################################
###############################################################

###############################################################
##    0.Create provider with proper credentials and roles    ##
##          You can switch to any other provider             ##
##            for list with supported ones use               ##
##      https://registry.terraform.io/browse/providers       ##
###############################################################

provider "aws" {                    
    region = "eu-central-1" #Here you can write your own region
    assume_role {
    # The role ARN within Backup account AssumeRole into.
    role_arn    = "arn:aws:iam::XXXXXXXXXXXXX:role/TerraformApplyRole"
  }
}

###############################################################
##      1. Create your VPC (Virtual Private Cloud)           ##
###############################################################

resource "aws_vpc" "Test_VPC" {    
  cidr_block = "10.0.0.0/16"           #Specify by provider

  tags = {
    Name = "Test_VPC"
  }
}

############################################################### 
##               2. Create Interenet Gateway                 ##
###############################################################

resource "aws_internet_gateway" "gate" {    
  vpc_id = aws_vpc.Test_VPC.id

  tags = {
    Name = "gateway" 
  }
}

###############################################################
##              3. Create Custom Route Table                 ##
###############################################################

resource "aws_route_table" "Test_Route_Table" {
  vpc_id = aws_vpc.Test_VPC.id

  route {
    cidr_block = "10.0.1.0/24"
    gateway_id = aws_internet_gateway.gate.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_internet_gateway.gate.id #Optional
  }

  tags = {
    Name = "Test_Route_Table"
  }
}

################################################################
##                    4. Create a Subnet                      ##
################################################################    

resource "aws_subnet" "sub-1" {
  vpc_id = aws_vpc.Test_VPC.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-central-1a"

  tags = {
    name = "subnet-1"
  }
}

################################################################
##            5. Associate Subnet with Route Table            ##
################################################################

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.sub-1.id
  route_table_id = aws_route_table.Test_Route_Table.id
}

################################################################
##      6. Create Security Group to allow ports               ##
##            22(SSH), 80(HTTP), 443(HTTPS)                   ##
##        they can vary depends from the demand               ##
################################################################

resource "aws_security_group" "allow_web" {
  name        = "allow_web"
  description = "Allow WEB traffic"
  vpc_id      = aws_vpc.Test_VPC.id

    ingress {
    description      = "SSH to VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]    #Optional: Here you can apply specific IP if needed for security reasons!
  }
   
   ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      =  ["0.0.0.0/0"]   #Optional: Here you can apply specific IP if needed for security reasons!
  }
  
  ingress {
    description      = "HTTPS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      =  ["0.0.0.0/0"]   #Optional: Here you can apply specific IP if needed for security reasons!
  }

  egress {                              #You can specify egress traffic if you need
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web_traffic"
  }
}

################################################################
##          7. Create a network interface with an IP          ##
##                 from the Subnet range                      ##
################################################################

resource "aws_network_interface" "web-server" {
  subnet_id       = aws_subnet.sub-1.id
  private_ips     = ["10.0.1.50"]    #You can assign an specific IP 
  security_groups = [aws_security_group.allow_web.id]

}

################################################################
##        8. Assign an elastic IP to the network interface    ##
##             (From step #7) for Security reasons            ##
################################################################

resource "aws_eip" "elasticip" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gate]
}

################################################################
##         9. Create EC2 instance with Ubuntu "ami"           ##
##                 and install/enable apache2                 ##
################################################################

resource "aws_instance" "web-server" {
  ami = "Specify an AMI(Ubuntu,Debian&etc.)"
  instance_type = "t2.micro"                  #freetier
  availability_zone = "eu-central-1a"
  key_name = "Specify key to access"

  network_interface {                    #attach the network
    device_index = 0
    network_interface_id = aws_network_interface.web-server.id
  }

################################################################
##            10. Create the userdata and install             ##   
##                  the services that you need                ##
################################################################

  user_data = <<-EOF              
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl enable --now apache2 
              sudo bash -c 'echo Web Server Test > /var/www/html/index.html'
              EOF

    tags = {
      name = "web-server"
    }

}