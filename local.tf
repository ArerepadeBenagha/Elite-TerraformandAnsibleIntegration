locals {
  # Common tags to be assigned to all resources
  common_tags = {
    Service     = "Elite Technology Services"
    Owner       = "EliteInfra"
    Department  = "IT"
    Company     = "EliteSolutions LLC"
    ManagedWith = "Terraform"
    Casecode    = "es20"
  }
  # network tags to be assigned to all resources
  network = {
    Service     = "Elite Technology Services"
    Owner       = "EliteInfra"
    Department  = "IT"
    Company     = "EliteSolutions LLC"
    ManagedWith = "Terraform"
    Casecode    = "es20"
  }
  # application tags to be assigned to all resources
  application = {
    app_name = "publicapp"
    location = "us-east-2"
    alias    = "Dev"
    ec2      = "public"
  }
  instance_type = "t2.micro"
}