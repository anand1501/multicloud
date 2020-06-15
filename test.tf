provider "aws" {
  region = "ap-south-1"
  profile = "Anand"
}

resource "aws_security_group" "my_httpd_sg" {
  name        = "my_httpd_sg"
ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
tags = {
    Name = "my_httpd_sg"
  }
}



resource "aws_instance" "web" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name 	=  "mykey1"
  security_groups = [ "my_httpd_sg" ]

   connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("/root/mykey1.pem")
    host     = aws_instance.web.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }
  


  tags = {
    Name = "lwos1"
  }
}


resource "aws_ebs_volume" "esb1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1
  tags = {
    Name = "lwebs"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.esb1.id}"
  instance_id = "${aws_instance.web.id}"
  force_detach = true
}

output "myos_ip" {
	value = aws_instance.web.public_ip
}

resource "null_resource" "nulllocal2"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.web.public_ip} > publicip.txt"
  	}
}


resource "null_resource" "nullremote3"  {

 depends_on = [
    aws_volume_attachment.ebs_att,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("/root/mykey1.pem")
    host     = aws_instance.web.public_ip
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/anand1501/multicloud.git /var/www/html/"
    ]
  }
}

output "ebs_name" {
	value = aws_ebs_volume.esb1.id
}

resource "aws_s3_bucket" "myanand1122" {
  bucket = "myanand1122"
  acl    = "public-read"
tags = {
    Name = "myanand1122"
  }
}

locals {
  s3_origin_id = "myS3Origin"
}

output "myanand1122" {
  value = aws_s3_bucket.myanand1122
}

resource "aws_s3_bucket_object" "object" {
  bucket = "${aws_s3_bucket.myanand1122.bucket}"
  key    = "anand.jpg"
  source = "/root/Desktop/terraform/anand.jpg"
  acl	 = "public-read"
}


resource "aws_cloudfront_distribution" "mycf" {
  origin {
    domain_name = "${aws_s3_bucket.myanand1122.bucket_regional_domain_name}"
    origin_id   = "${aws_s3_bucket.myanand1122.id}"
  }


  enabled             = true
  is_ipv6_enabled     = true
  comment             = "S3 Web Distribution"




  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.myanand1122.id}"




    forwarded_values {
      query_string = false




      cookies {
        forward = "none"
      }
    }
    
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }




  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN"]
    }
  }




  tags = {
    Name        = "Web-CF-Distribution"
    Environment = "Production"
  }




  viewer_certificate {
    cloudfront_default_certificate = true
  }




  depends_on = [
    aws_s3_bucket.myanand1122
  ]
}


resource "aws_ebs_snapshot" "ebs_snapshot" {
  volume_id   = "${aws_ebs_volume.esb1.id}"
  description = "Snapshot of our EBS volume"
  
  tags = {
    env = "Production"
  }



  depends_on = [
    aws_volume_attachment.ebs_att
  ]
}


