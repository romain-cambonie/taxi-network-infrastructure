locals {
  product_information = {
    context : {
      product    = var.product
      service    = var.service
      start_date = "2023-01-31"
      end_date   = "unknown"
    }
    purpose : {
      disaster_recovery = "medium"
      service_class     = "bronze"
    }
    organization : {
      client = "taxi-aymeric"
    }
    stakeholders : {
      business_owner  = "romain-cambonie@gmail.com"
      technical_owner = "romain-cambonie@gmail.com"
      approver        = "romain-cambonie@gmail.com"
      creator         = "terraform"
      team            = "romain-cambonie"
    }
  }
  repository = "taxi-network-infrastructure"
}

locals {
  productTitle = title(replace(local.product_information.context.product, "_", " "))
  serviceTitle = title(replace(local.product_information.context.service, "_", " "))
  domainName   = "taxi-gestion.com"
}

locals {
  service = {
    taxi_aymeric = {
      name = var.service
      client = {
        name  = "client"
        title = "client"
      }
    }
  }
}
