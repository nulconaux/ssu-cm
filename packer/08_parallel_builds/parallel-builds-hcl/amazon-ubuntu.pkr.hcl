source "amazon-ebs" "aws-ubuntu" {
    access_key = ""
    secret_key = ""
    region = "us-east-1"
    instance_type = "t2.micro"
    ami_name = "docker-app_packer-{{timestamp}}"
    source_ami_filter {
        filters = {
            virtualization-type = "hvm"
            name = "ubuntu/images/*ubuntu-focal-20.04-amd64-server-*"
            root-device-type = "ebs"
        }
        owners = ["099720109477"]
        most_recent = true
    }
    ssh_username = "ubuntu"
}
