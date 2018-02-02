variable "project_name" {
  description = "Project Name, test"
}

variable "ssh_private_key" {
  description = "SSH Private Key File"
}

variable "ssh_public_key" {
  description = "SSH Public Key File"
}

variable "ssh_user" {
  default     = "centos"
  description = "SSH User Name"
}

variable "num_nodes" {
  default = 3
  description = "Number of nodes to deploy"
}

variable "availability_zone" {
  default = "ca-central-1a"
  description = "AWS availability zone"
}

resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/24"
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}

resource "aws_subnet" "default" {
  availability_zone = "${var.availability_zone}"
  cidr_block = "${aws_vpc.default.cidr_block}"
  vpc_id     = "${aws_vpc.default.id}"
}

resource "aws_route" "default" {
  route_table_id         = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

resource "aws_security_group" "default" {
  name   = "${var.project_name}"
  vpc_id = "${aws_vpc.default.id}"

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
  }

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    self = true
  }
}

resource "aws_network_interface" "default" {
  security_groups = ["${aws_security_group.default.id}"]
  subnet_id       = "${aws_subnet.default.id}"
  count           = "${var.num_nodes}"
}

resource "aws_eip" "default" {
  network_interface = "${aws_network_interface.default.*.id[count.index]}"
  count             = "${var.num_nodes}"
}

resource "aws_key_pair" "default" {
  key_name   = "${var.project_name}"
  public_key = "${file("${var.ssh_public_key}")}"
}

resource "aws_ebs_volume" "data" {
  availability_zone  = "${var.availability_zone}"
  size = 40
  tags {
    project = "${var.project_name}"
  }
  count = "${var.num_nodes}"
}

resource "aws_instance" "kafka" {
  availability_zone  = "${var.availability_zone}"
  ami           = "ami-161ea572"
  instance_type = "t2.large"
  key_name      = "${aws_key_pair.default.key_name}"
  count         = "${var.num_nodes}"

  tags {
    kafka = "node"
    zookeeper = "node"
    Index = "${count.index}"
  }

  network_interface {
    device_index         = 0
    network_interface_id = "${aws_network_interface.default.*.id[count.index]}"
  }

  root_block_device {
    delete_on_termination = true
    volume_size           = 32
    volume_type           = "standard"
  }
}

resource "aws_volume_attachment" "data_att" {
  device_name = "/dev/sdh"
  volume_id = "${aws_ebs_volume.data.*.id[count.index]}"
  instance_id = "${aws_instance.kafka.*.id[count.index]}"
  force_detach = true
  count = "${var.num_nodes}"
}

output "ssh_private_key" {
  value = "${var.ssh_private_key}"
}

output "ssh_user" {
  value = "${var.ssh_user}"
}

output "addresses" {
  value = "${aws_eip.default.*.public_ip}"
}
