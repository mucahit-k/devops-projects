#! /bin/bash

yum update -y
amazon-linux-extras install docker -y
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user
curl -L "https://github.com/docker/compose/releases/download/1.26.2/docker-compose-$(uname -s)-$(uname -m)" \
-o /usr/bin/docker-compose
chmod +x /usr/bin/docker-compose

FOLDER="https://raw.githubusercontent.com/mucahit-k/devops-projects/master/projects/202-dockerization-bookstore-api-on-python-flask-mysql/"
curl -s --create-dirs -o "/home/ec2-user/app/Dockerfile" -L "$FOLDER"Dockerfile
curl -s --create-dirs -o "/home/ec2-user/app/docker-compose.yml" -L "$FOLDER"docker-compose.yml
curl -s --create-dirs -o "/home/ec2-user/app/bookstore-api.py" -L "$FOLDER"bookstore-api.py
curl -s --create-dirs -o "/home/ec2-user/app/requirements.txt" -L "$FOLDER"requirements.txt

cd /home/ec2-user/app
docker build -t koca/bookstore-api:latest .
docker-compose up 

