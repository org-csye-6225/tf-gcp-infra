# Terraform Infrastructure

This Terraform configuration manages networking infrastructure on Google Cloud Platform (GCP) using Infrastructure as Code (IaC) principles.

## Overview

This Terraform configuration creates Virtual Private Clouds (VPCs) and associated resources, including subnetworks and routes, in a specified GCP project and region. It allows for dynamic creation of VPCs with customizable configurations.

## Prerequisites

Before using this Terraform configuration, make sure you have:

- Terraform installed on your local machine.
- Google Cloud SDK installed and configured with appropriate credentials.
- Permissions to create resources in the target GCP project.

## Initial Setup

1. Install Google Cloud SDK if not already installed: [Google Cloud SDK Installation Guide](https://cloud.google.com/sdk/docs/install)
   
2. Authenticate with Google Cloud Platform using `gcloud` command-line tool:
   
    ```
    gcloud auth application-default login
    ```

    This command prompts you to authenticate via a web browser and sets up application default credentials. It's suitable for local development and testing purposes.

## Usage

1. Clone the repository to your local machine:

    ```
    git clone `https://github.com/org-csye-6225/tf-gcp-infra.git`
    ```

2. Navigate to the directory containing the Terraform configuration files:

    ```
    cd tf-gcp-infra
    ```

3. Initialize Terraform:

    ```
    terraform init
    ```

4. Review and customize the variables in `variables.tf` according to your requirements.

5. Review and customize the main configuration files (`main.tf`, `provider.tf`)

6. Plan the Terraform execution to preview the changes:

    ```
    terraform plan
    ```

7. Apply the Terraform configuration to create the networking infrastructure:

    ```
    terraform apply
    ```

8. Verify that the resources have been created as expected in the GCP Console or using Terraform outputs.

## Configuration

### Variables

- **`project_id`**: The name of the GCP project where resources will be created.
- **`region_id`**: The region in which resources will be provisioned.
- **`vpc_name`**: The name of the VPC to be created.
- **`vpc_routing_mode`**: The routing mode for the VPC (REGIONAL or GLOBAL).
- **`private_subnet`**: The name of the private subnet.
- **`public_subnet`**: The name of the public subnet.
- **`vpcs`**: A map of VPC configurations, including name, routing mode, and subnets.

### Files

- **`main.tf`**: The main Terraform configuration file defining resources such as VPCs, subnets, and routes.
- **`variables.tf`**: Defines input variables used in the Terraform configuration.
- **`provider.tf`**: Specifies the GCP provider configuration.

### Modules
- **`modules/vpc`**: Contains module-specific configurations for creating VPCs.
