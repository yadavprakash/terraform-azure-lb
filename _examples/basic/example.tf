provider "azurerm" {
  features {}
}

module "resource_group" {
  source      = "git::https://github.com/opsstation/terraform-azure-resource-group.git?ref=v1.0.0"
  name        = "load-basiffc"
  environment = "tested"
  location    = "North Europe"
}

module "vnet" {
  source              = "git::https://github.com/opsstation/terraform-azure-vnet.git?ref=v1.0.0"
  name                = "app"
  environment         = "test"
  resource_group_name = module.resource_group.resource_group_name
  location            = module.resource_group.resource_group_location
  address_spaces      = ["10.0.0.0/16"]
}

module "subnet" {
  source = "git::https://github.com/opsstation/terraform-azure-subnet.git?ref=v1.0.1"

  name                 = "app"
  environment          = "test"
  resource_group_name  = module.resource_group.resource_group_name
  location             = module.resource_group.resource_group_location
  virtual_network_name = join("", module.vnet[*].vnet_name)

  #subnet
  subnet_names    = ["subnet2"]
  subnet_prefixes = ["10.0.1.0/24"]

  # route_table
  enable_route_table = true
  route_table_name   = "default_subnet"
  routes = [
    {
      name           = "rt-test"
      address_prefix = "0.0.0.0/0"
      next_hop_type  = "Internet"
    }
  ]
}

module "network_security_group" {
  source                  = "git::https://github.com/opsstation/terraform-azure-network-security-group.git?ref=v1.0.0"
  name                    = "app"
  environment             = "test"
  resource_group_name     = module.resource_group.resource_group_name
  resource_group_location = module.resource_group.resource_group_location
  subnet_ids              = module.subnet.subnet_id
  inbound_rules = [
    {
      name                       = "ssh"
      priority                   = 101
      access                     = "Allow"
      protocol                   = "Tcp"
      source_address_prefix      = "*"
      source_port_range          = "*"
      destination_address_prefix = "0.0.0.0/0"
      destination_port_range     = "*"
      description                = "ssh allowed port"
    },
    {
      name                       = "https"
      priority                   = 102
      access                     = "Allow"
      protocol                   = "*"
      source_address_prefix      = "VirtualNetwork"
      source_port_range          = "80,443"
      destination_address_prefix = "0.0.0.0/0"
      destination_port_range     = "22"
      description                = "ssh allowed port"
    }
  ]
}

module "virtual-machine" {
  source = "git::https://github.com/opsstation/terraform-azure-virtual-machine.git?ref=v1.0.0"
  #Tags
  name        = "apffftfrp"
  environment = "test"
  label_order = ["environment", "name"]
  #Common
  is_vm_linux                     = true
  enabled                         = true
  machine_count                   = 1
  resource_group_name             = module.resource_group.resource_group_name
  location                        = module.resource_group.resource_group_location
  disable_password_authentication = true
  #Network Interface
  subnet_id                     = module.subnet.subnet_id
  private_ip_address_version    = "IPv4"
  private_ip_address_allocation = "Dynamic"
  availability_set_enabled      = true
  platform_update_domain_count  = 7
  platform_fault_domain_count   = 3
  #Public IP
  public_ip_enabled = true
  sku               = "Standard"
  allocation_method = "Static"
  ip_version        = "IPv4"
  #Virtual Machine
  vm_size        = "Standard_B1s"
  public_key     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDOLqF1HXeOiFz8r/oO9WUqvmJ695VbK1zlLBIaZ+CzayMXIpXb1nl91zsGWE8JIRQQRTuPH898tsuqK+xoYNqFn/o2r44FGKXbhTr9aelA8Rw7LxPukDmgXGaL4BBymOPZIGX7RSdc1+OKyLErmMHyhz3hTYV/J9UKj9Zc3AjwisfuH1wMvRyANGP5wRFrPr08om+vOnpGoT66OCZcJs/OoG9VjlddMblj+yeJNPSBvj7pyZIQYYtrME1iogIaSjZBEb4i7ZiPZZhvD9R5bP+/lyzv8nm0pPoKWLbJHQgG+B3cY9/fE/4kugsYrlkjegvIhDCM9+WW1JP27cyQqq87zH2g32QM6n8gPP3bMMjQViFxgiubTz6PI+/KHCSfcI5XAnlGjO+6s6LHUvBxtNl0S3gsPBtMwpa8oEg1XTspwjiCqGe/3cHQg9SjDnmnKihf5Odpn6Ipy9ugMxTDUdAgte4u10W+BKdkC6Rn28enFt5zV7mGE0rdEg4DLPTkpR0= abhi@abhi"
  admin_username = "ubuntu"
  # admin_password                = "P@ssw0rd!123!" # It is compulsory when disable_password_authentication = false
  caching                         = "ReadWrite"
  disk_size_gb                    = 30
  storage_image_reference_enabled = true
  image_publisher                 = "Canonical"
  image_offer                     = "0001-com-ubuntu-server-focal"
  image_sku                       = "20_04-lts"
  image_version                   = "latest"
  enable_disk_encryption_set      = false
  #key_vault_id                   = key_vault_idmodule.vault.id
  addtional_capabilities_enabled = true
  ultra_ssd_enabled              = false
  enable_encryption_at_host      = false
  key_vault_rbac_auth_enabled    = false


  # Extension
  extensions = [{
    extension_publisher            = "Microsoft.Azure.Extensions"
    extension_name                 = "hostname"
    extension_type                 = "CustomScript"
    extension_type_handler_version = "2.0"
    auto_upgrade_minor_version     = true
    automatic_upgrade_enabled      = false
    settings                       = <<SETTINGS
    {
      "commandToExecute": "hostname && uptime"
     }
     SETTINGS
  }]

}


module "load-balancer" {
  source = "../.."
  #Labels
  name        = "apphuyt"
  environment = "test"
  #Common
  enabled             = true
  resource_group_name = module.resource_group.resource_group_name
  location            = module.resource_group.resource_group_location
  #Load Balancer
  frontend_name = "mypublicIP"
  lb_sku        = "Basic"
  # Public IP
  ip_count          = 1
  allocation_method = "Static"
  sku               = "Basic"
  nat_protocol      = "Tcp"
  public_ip_enabled = true
  ip_version        = "IPv4"
  #Backend Pool
  is_enable_backend_pool = true
  ip_configuration_name_association = ["app-test-public-ip-1", "app-test-public-ip-2"]
  remote_port = {
    ssh   = ["Tcp", "22"]
    https = ["Tcp", "80"]
  }

  lb_port = {
    http  = ["80", "Tcp", "80"]
    https = ["443", "Tcp", "443"]
  }

  lb_probe = {
    http  = ["Tcp", "80", ""]
    http2 = ["Http", "1443", "/"]
  }

  depends_on = [module.resource_group]
}

