/**********
 * CONFIG *
 **********/
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.10.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  skip_provider_registration = true
  subscription_id            = "f7dd0133-165c-48f9-a85d-0ec6f7cb632b"
  features {}
}

/***************
 * DATA LOOKUP *
 ***************/
data "cloudinit_config" "hostip" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/x-shellscript"
    filename     = "scripts"
    content = templatefile("./scripts/script.sh",
      {
        hostip   = azurerm_linux_virtual_machine.Linuxvm.public_ip_address
        key_path = var.key_path
    })
  }
}

/**********
 * LOCALS *
 **********/
locals {
  # Common tags to be assigned to all resources
  common_tags = {
    Service     = "devOps"
    Owner       = "elitesolutionsit"
    environment = "Development"
    ManagedWith = "terraform"
  }
  buildregion             = lower("EASTUS2")
  server                  = "elite"
  elite_general_resources = "elite-vm-dev"
}

/********
 * VNET *
 ********/
resource "azurerm_resource_group" "elite_general_network" {
  name     = var.elite_general_network
  location = var.location
}

resource "azurerm_network_security_group" "elite_devnsg" {
  name                = var.elite_devnsg
  location            = azurerm_resource_group.elite_general_network.location
  resource_group_name = azurerm_resource_group.elite_general_network.name
}

resource "azurerm_virtual_network" "elitedev_vnet" {
  name                = var.elitedev_vnet
  location            = azurerm_resource_group.elite_general_network.location
  resource_group_name = azurerm_resource_group.elite_general_network.name
  address_space       = var.address_space

  tags = local.common_tags
}

resource "azurerm_route" "route" {
  name                = "route1"
  resource_group_name = azurerm_resource_group.elite_general_network.name
  route_table_name    = azurerm_route_table.elite_rtb.name
  address_prefix      = "10.0.0.0/16"
  next_hop_type       = "VnetLocal"
}

resource "azurerm_route_table" "elite_rtb" {
  name                = var.elite_rtb
  location            = azurerm_resource_group.elite_general_network.location
  resource_group_name = azurerm_resource_group.elite_general_network.name
}

resource "azurerm_subnet" "application_subnet" {
  name                 = var.application_subnet
  resource_group_name  = azurerm_resource_group.elite_general_network.name
  virtual_network_name = azurerm_virtual_network.elitedev_vnet.name
  address_prefixes     = var.address_prefixes_application
}

resource "azurerm_subnet_route_table_association" "elitedev_rtb_assoc_application" {
  subnet_id      = azurerm_subnet.application_subnet.id
  route_table_id = azurerm_route_table.elite_rtb.id
}

resource "azurerm_subnet_network_security_group_association" "elite_devnsg_assoc_application_subnet" {
  subnet_id                 = azurerm_subnet.application_subnet.id
  network_security_group_id = azurerm_network_security_group.elite_devnsg.id
}

/******
 * VM *
 ******/
resource "azurerm_resource_group" "elite_general_resources" {
  name     = local.elite_general_resources
  location = var.location
}

resource "azurerm_network_interface" "labnic" {
  name                = join("-", [local.server, "lab", "nic"])
  location            = local.buildregion
  resource_group_name = azurerm_resource_group.elite_general_resources.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.application_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.labpip.id
  }
}

resource "azurerm_public_ip" "labpip" {
  name                = join("-", [local.server, "lab", "pip"])
  resource_group_name = azurerm_resource_group.elite_general_resources.name
  location            = local.buildregion
  allocation_method   = "Static"

  tags = local.common_tags
}


resource "azurerm_linux_virtual_machine" "Linuxvm" {
  name                  = join("-", [local.server, "linux", "vm"])
  resource_group_name   = azurerm_resource_group.elite_general_resources.name
  location              = local.buildregion
  size                  = "Standard_DS1"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.labnic.id]

  connection {
    type        = "ssh"
    user        = "adminuser"
    private_key = file(var.ssh_private_key)
    host        = (self.public_ip_address)
  }

  provisioner "file" {
    source      = "./scripts/script.sh"
    destination = "/tmp/script.sh"
  }

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ${var.user} -i '${self.public_ip_address},' --private-key ${var.ssh_private_key} playbook-nginx.yml -vv"
  }

  admin_ssh_key {
    username   = "adminuser"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDHhQOAaTjgDg3Tfupm9pwLFbjo/uhHU5Ll44Qdf7wGmHKbvTT/LS5v0AxeDP7aJQsCnd8EK8m+hnNddy7kxDjCOxT5FlIrvK/bgp2pin2luMGGL5NVw1MFRW3B+hAdr+lhxi4YX4LvcaMe6zA++huRLu4xazHEKiOs0xSwISqDI66IntVMv+1OOpv0WZZLP2cuTFIeoBSvPuY5XPweemh9GSv52wxaNjo2KzvDtjVCuCHTE4fQwddH4gokJ2JrBZNTulIqQ5n1ML7j2AXxEa5gZwF30zgTtOZ0ovE/noyoCWwKUw5U7K8J2j4E2TD6/QtvCWvZ48sM/foexxZKZaVTAxPLCFmUxlWCyDa5Wg6b6NWA3Ww/ZDJOgnmo77pbcvOIPNafnZmFnTbQFIgUJ30g3depJ0PMkYcmByAMaFRQPPebctog5DoiSTJdZ12phOE/aew4VW4Jhiy1spfc3fc3IJaaBigaCM8ICSybEEiQSqO4Wc3zAJ8IpirpaNVxhDU= lbena@LAPTOP-QB0DU4OG"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    offer     = "0001-com-ubuntu-server-focal"
    publisher = "Canonical"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}

/*************
 * VARIABLES *
 *************/
variable "ssh_private_key" {
  type    = string
  default = "/home/devopslab/.ssh/simpleserverkey"
}

variable "key_path" {
  type    = string
  default = "/root/.ssh/known_hosts/simpleserverkey"
}

variable "path" {
  type    = string
  default = "/root/.ssh/known_hosts"
}

variable "user" {
  type    = string
  default = "adminuser"
}

variable "elite_general_network" {
  type    = string
  default = "elitegeneralnetwork"
}

variable "location" {
  type    = string
  default = "EASTUS2"
}

variable "elite_devnsg" {
  type    = string
  default = "elite_devnsg"
}

variable "elitedev_vnet" {
  type    = string
  default = "elitedev_vnet"
}

variable "address_space" {
  type    = list(string)
  default = ["10.0.0.0/16"]
}

variable "elite_rtb" {
  type    = string
  default = "elite_rtb"
}

variable "application_subnet" {
  type    = string
  default = "application_subnet"
}


variable "address_prefixes_application" {
  type    = list(string)
  default = ["10.0.2.0/24"]
}

variable "source_address_prefix" {
  type    = string
  default = "70.114.65.185/32"
}

variable "destination_address_prefix" {
  type    = string
  default = "VirtualNetwork"
}

/*********
 * RULES *
 *********/
resource "azurerm_network_security_rule" "SSH" {
  name                        = "SSH"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.source_address_prefix
  destination_address_prefix  = var.destination_address_prefix
  resource_group_name         = azurerm_resource_group.elite_general_network.name
  network_security_group_name = azurerm_network_security_group.elite_devnsg.name
}

resource "azurerm_network_security_rule" "HTTP" {
  name                        = "HTTP"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = var.source_address_prefix
  destination_address_prefix  = var.destination_address_prefix
  resource_group_name         = azurerm_resource_group.elite_general_network.name
  network_security_group_name = azurerm_network_security_group.elite_devnsg.name
}
