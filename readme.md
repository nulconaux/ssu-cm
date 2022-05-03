[![CodeFactor](https://www.codefactor.io/repository/github/nulconaux/ssu-cm/badge)](https://www.codefactor.io/repository/github/nulconaux/ssu-cm) [![Lint Repository Source Code](https://github.com/nulconaux/ssu-cm/actions/workflows/linters.yml/badge.svg)](https://github.com/nulconaux/ssu-cm/actions/workflows/linters.yml) [![Sonar Cloud](https://github.com/nulconaux/ssu-cm/actions/workflows/sonarcloud.yml/badge.svg)](https://github.com/nulconaux/ssu-cm/actions/workflows/sonarcloud.yml)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=nulconaux_ssu-cm&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=nulconaux_ssu-cm)


<p align="center">
 <img src="https://user-images.githubusercontent.com/29449749/125477424-0a05ad03-20a0-4e6b-85e1-58b683d823df.png">
 <br><br>
 <a href="https://docs.google.com/presentation/d/1NmYV6Mon-ZOvfmNns8_j4nLCUwK3TS7aZPncHUZvncs/edit?usp=sharing">SSU Configuration Management: Packer & Ansible</a>
</p>


# Nowaday
There are two major parts involved: `ansible` and `packer`.

Packer is used to create an image from defined base image, copying ansible directory 
to that image and running locally a given ansible playbook.

Ansible is used to keep codified configuration of 
* 'immutable' or occasionally modified image components(like packages, static 
    parts of configuration etc.);
*  'dynamic' configuration for instances, depending on a set of instance properties
    * AWS region
    * Environment
    * Instance tags
    * etc.

## Prepare

* Export samples
```bash
$ echo "export EDITOR=vim" >> ~/.bashrc
$ source ~/.bashrc
$ export AWS_PROFILE=
$ export AWS_ACCESS_KEY_ID=
$ export AWS_SECRET_ACCESS_KEY=
$ export AWS_DEFAULT_REGION=eu-west-1

$ echo "127.0.0.1" > ~ansible/inventory/hosts
$ export ANSIBLE_ANSIBLE_SSH_KEYDIR=`pwd`
$ export ANSIBLE_INVENTORY_ENABLED=amazon.aws.aws_ec2

$ ANSIBLE_PIPELINING(/etc/ansible/ansible.cfg) = True
$ DEFAULT_HOST_LIST(/etc/ansible/ansible.cfg) = ['/etc/ansible/hosts']
$ DEFAULT_REMOTE_USER(/etc/ansible/ansible.cfg) = myuser
$ RETRY_FILES_ENABLED(/etc/ansible/ansible.cfg) = False
$ ANSIBLE_VAULT_PASSWORD_FILE(/etc/ansible/ansible.cfg) =~/bin/ansible-vault-pass

$ export PACKER_LOG_PATH="packer.log"
$ export PACKER_LOG=1
```


* AWS Account and Cli

```bash
pip install awscli
aws configure --profile ssu-cm
export  AWS_PROFILE=ssu-cm
aws get-caller-identity
```


* [Packer](https://learn.hashicorp.com/tutorials/packer/get-started-install-cli#installing-packer)

```bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install packer
sudo cp /usr/bin/packer /usr/local/bin/packer
```

```bash
which packer
/usr/local/bin/packer
packer version
Packer v1.7.2
packer -autocomplete-install
```


* [VirtualBox](https://www.virtualbox.org/wiki/Downloads)


* [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)

[Install Ansible by using virtualenv](https://clouddocs.f5.com/products/orchestration/ansible/devel/usage/virtualenv.html)

```bash
$ sudo easy_install pip
$ sudo pip install -r ./requirements.txt
$ ansible --version
```

##  Troubleshooting SSH Connections
Sometimes when attempting an initial Ansible ping, it can fail in a very confusing way. If this happens, try adding something like this to your `~/.ssh/config` file:

```yaml
Host <hostname-prefix>*
  Port 22
  User <ssh-login-username>
  StrictHostKeyChecking=no
  UserKnownHostsFile=/dev/null
```

# How to develop AMIs with Packer and Ansible
Things I wish they'd told me

## Use in packer templates

Before using ansible provisioning in `packer` next packages should be installed into image:
* ***python*** >= 2.7
* ***python-setuptools***
* ***python-pip***
* ***ansible*** >= 2.4

```
{
  ...
  "provisioners": [
    ...
    {
      "type": "shell",
      "inline": [
        "sleep 10",
        "sudo yum install -y python2 python-setuptools",
        "curl 'https://bootstrap.pypa.io/get-pip.py' | sudo python",
        "sudo pip install ansible"
      ]
    },
    {
      "type": "ansible-local",
      "playbook_file": "../ansible/run_playbook.yaml",
      "playbook_dir": "../ansible",
      "role_paths": [
        "../ansible/roles"
      ],
      "clean_staging_directory": true
    }
    ...
  ]
  ...
}
``` 

## Difference between ansible running remotely and locally

When packer starts ansible for `ansible-local` provisioner internal ansible variable 
`inventory_hostname` is '127.0.0.1'. This way we can distinguish between AMI builds
and regular ansible runs in role files:

```
- name: Example AMI stage
  block:
    - name: Run on image build only
      command: echo "local"
  when: inventory_hostname == '127.0.0.1'
  
- name: Example live instance stage
  block:
    - name: Run on remote instance only
      command: echo "remote"
  when: inventory_hostname != '127.0.0.1'  
```

## Remote 'live' systems operations

We are using dynamic inventory based on ansible recommended script with a minor changes in code and configuration.
Example:
```
⟫ AWS_PROFILE=teg EC2_INI_PATH=./inventory/ec2.ini ANSIBLE_INVENTORY=./inventory/ec2.py \
    ansible -m ping tag_Project_SSU_CM
teg_devops_eu_west_1_openvpn | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
...
```

## Develop the Ansible role locally
When you try to debug something in packer by making a change in the Ansible role
you want to see the effect immediately. To do that just symlink your project
in `~/.ansible/roles` with whatever name you are referencing it with.
So, for example, a project refered to as `ansible-role-test` which is locally in `ansible-role-test`:
```
`ln -s $(pwd)/ansible-role-test ~/.ansible/roles/ansible-role-test`
```

## Don't run packer with `-debug`
If you do this IT WILL ASK YOU FOR INPUT BETWEEN EVERY STEP.
This is perhaps one of the most annoying debug behavior ever.

##  Take advantage of the Ansible debugger with `-on-error=ask` and a specified keypair

If you've got a box set up (maybe from running packer with `-on-error=ask`) you can run the [ansible debugger](https://docs.ansible.com/ansible/latest/user_guide/playbooks_debugger.html). It's a lot like `pdb` for Ansible.

Now packer will run until an error and then ask you what to do:
```
==> my-test-ami: [c] Clean up and exit, [a] abort without cleanup, or [r] retry step (build may fail even if retry succeeds)?
```

By specifying the keypair you can use a key you already have in AWS to SSH in:
```
  "builders": [{
            "ssh_keypair_name": "the_key_is_automation",
            "ssh_private_key_file": "~/.ssh/tempKeys/the_key_is_automation.pem",
            "name": "my-test-ami",
            "type": "amazon-ebs",
            ...
```

Taking a look at what's wrong becomes as easy as SSH:
```
ssh -i ~/.ssh/tempkeys/the_key_is_automation.pem ec2-user@xx.xx.xx.xx
```

## Delete the AMI created by Packer

### First, get the AMI ID value using:

```
aws ec2 describe-images --filters "Name=tag:Name,Values=my-server*" -region=eu-west-1 --query 'Images[*].{ID:ImageId}'
```

### Then delete the AMI

```
aws ec2 deregister-image --image-id ami-<value>
```

## Launch an instance from the AMI
First, I launch a new instance from my AMI. I use the same subnet as for Packer, take the ID of the Dedicated Host I created earlier on, and I specify an IAM Role, which has the required permissions to use SSM.

```
aws ec2 run-instances --instance-type mac1.metal \
                      --subnet-id subnet-0d3d002af8EXAMPLE \
                      --image-id ami-0d6fb7542bb0a8da3 \
                      --region us-east-2 \
                      --placement HostId=h-03464da766df06f5c \
                      --iam-instance-profile Name=SSMInstanceRole
```

## Connecting to the instance
I can start an SSH session to the instance via SSM with the following command:

```
aws ssm start-session --target <YOUR_INSTANCE_ID> --region us-east-2
```
## [Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)

When using session_manager the machine running Packer must have the AWS Session Manager Plugin installed and within the users' system path. Connectivity via the session_manager interface establishes a secure tunnel between the local host and the remote host on an available local port to the specified ssh_port. See Session Manager Connections for more information.

## Assume Role Configuration

```
source "amazon-ebs" "example" {
    assume_role {
        role_arn     = "arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME"
        session_name = "SESSION_NAME"
        external_id  = "EXTERNAL_ID"
    }
}
```

## Packer Filters

Examples

```
  security_group_filter {
    filters = {
      "tag:Class": "packer"
    }
  }
  vpc_filter {
    filters = {
      "tag:Name": "myVPC",
      "isDefault": "false"
    }
  }
  subnet_filter {
    filters = {
      "state": "available",
      "tag:Name": "*public*"
    }
    random = true
  }
```

This example uses a amazon-ami data source rather than a specific AMI.
this allows us to use the same filter regardless of what region we're in,
among other benefits.

```
data "amazon-ami" "example" {
  filters = {
    virtualization-type = "hvm"
    name                = "*Windows_Server-2012*English-64Bit-Base*"
    root-device-type    = "ebs"
  }
  owners      = ["amazon"]
  most_recent = true
  # Access Region Configuration
  region      = "us-east-1"
}
```

```
  source_ami_filter {
    filters = {
       virtualization-type = "hvm"
       name = "ubuntu/images/\*ubuntu-xenial-16.04-amd64-server-\*"
       root-device-type = "ebs"
    }
    owners = ["099720109477"]
    most_recent = true
  }
```

## Limiting Playbook/Task Runs
When writing Ansible, sometimes it is tedious to make a change in a playbook or task, then run the playbook It can sometimes be very helpful to run a module directly as shown above, but only against a single development host.

Limit to one or more hosts
This is required when one wants to run a playbook against a host group, but only against one or more members of that group.

Limit to one host

```sh
ansible-playbook playbooks/PLAYBOOK_NAME.yml --limit "host1"
```

Limit to multiple hosts

```sh
ansible-playbook playbooks/PLAYBOOK_NAME.yml --limit "host1,host2"
```

Negated limit. NOTE: Single quotes MUST be used to prevent bash interpolation.

```sh
ansible-playbook playbooks/PLAYBOOK_NAME.yml --limit 'all:!host1'
```

Limit to host group

```sh
ansible-playbook playbooks/PLAYBOOK_NAME.yml --limit 'group1'
```

## Limiting Tasks with Tags
Limit to all tags matching install

```sh
ansible-playbook playbooks/PLAYBOOK_NAME.yml --tags 'install'
```

Skip any tag matching sudoers

```sh
ansible-playbook playbooks/PLAYBOOK_NAME.yml --skip-tags 'sudoers'
```

Troubleshooting Ansible
http://docs.ansible.com/ansible/playbooks_checkmode.html


* Pre-commit

```bash
pip3 install pre-commit pre-commit-hooks setup-cfg-fmt
sudo apt install shellcheck
curl https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | sudo bash
pre-commit install
pre-commit run -a
```


Run GitHub SuperLinter localy
https://github.com/github/super-linter

```bash
export cm_repo_path=`pwd` \
    && echo "set cm_repo_path to $cm_repo_path" \
    && docker run -e RUN_LOCAL=true -v $cm_repo_path:/tmp/lint github/super-linter
```
