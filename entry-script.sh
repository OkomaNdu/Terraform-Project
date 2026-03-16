#!/bin/bash
sudo yum update -y && sudo yum install docker -y 
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ec2-user
sudo docker run -d -p 8080:80 nginx

