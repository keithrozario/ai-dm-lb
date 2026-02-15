# Google Cloud Load Balancing & Networking Demo

This repository contains Terraform configurations to deploy a comprehensive set of Google Cloud Networking and Load Balancing patterns. It demonstrates various ways to route traffic to serverless (Cloud Run) and VM-based (Managed Instance Group) backends, including advanced scenarios like Private Service Connect (PSC) and Load Balancer chaining using Internet NEGs.

## Architecture Overview

The infrastructure is designed to showcase different load balancing schemes and connectivity options:

1.  **Global External LB** routing to **Cloud Run**.
2.  **Regional External LB** routing to a **Regional Managed Instance Group (MIG)**.
3.  **Internal Regional LB** routing to the same MIG, exposed via **Private Service Connect (PSC)**.
4.  **Frontend LBs (Global & Regional)** using **Internet NEGs** to chain traffic to the backend Load Balancers.

### Network Topology

*   **Producer VPC (`ai-dm-vpc`):** Hosts the main application workloads (MIGs) and the Service Attachment.
*   **Consumer VPC (`ai-dm-internal-vpc`):** Simulates a consumer network that accesses the producer's services privately via a PSC Endpoint.

## Prerequisites

*   [Terraform](https://www.terraform.io/downloads.html) >= 1.0
*   [Google Cloud SDK (gcloud)](https://cloud.google.com/sdk/docs/install)
*   A Google Cloud Project
*   Appropriate IAM permissions to create Networking, Compute, and Cloud Run resources.

## Project Structure

### Core Configuration
*   `main.tf`: Provider configuration (Google & Google Beta) and backend setup (GCS).
*   `variables.tf`: Configuration variables (`project_id`, `region`, `stack_name`).
*   `services.tf`: Enables necessary GCP APIs (Compute, Storage, Cloud Run, Artifact Registry, etc.).

### Networking (VPC)
*   `network_producer_vpc.tf`: Defines the primary "Producer" VPC using the `vpc` module.
*   `network_consumer_vpc.tf`: Defines the "Consumer" VPC and the **PSC Endpoint** (`psc-endpoint`) to access services privately.
*   `vpc/`: Custom module to create VPCs, Subnets, Cloud NAT, and Firewall rules.

### Compute Backends
*   `backend_service_cloud_run.tf`:
    *   Builds a Docker image from `cloud_run_container/` (Python Flask app).
    *   Deploys it to **Cloud Run**.
    *   Creates a Serverless NEG.
*   `backend_service_mig.tf`:
    *   Creates subnetworks for VM instances.
    *   Calls the `regional-mig` module to create Managed Instance Groups.
*   `regional-mig/`: Custom module to deploy a Regional MIG with an Nginx "Hello World" page.

### Load Balancing Scenarios

#### 1. Global LB -> Cloud Run
*   **File:** `backend_lb_global.tf`
*   **Type:** Global External HTTP(S) Load Balancer (`EXTERNAL_MANAGED`)
*   **Target:** Cloud Run Service (via Serverless NEG)

#### 2. Regional LB -> VM MIG
*   **File:** `backend_lb_regional.tf`
*   **Type:** Regional External HTTP(S) Load Balancer (`EXTERNAL_MANAGED`)
*   **Target:** Regional Managed Instance Group
*   **Features:** Uses a Proxy-only subnet.

#### 3. Internal LB & Private Service Connect
*   **File:** `backend_lb_regional_internal.tf`
*   **Type:** Internal Regional HTTP(S) Load Balancer (`INTERNAL_MANAGED`)
*   **Target:** Regional Managed Instance Group
*   **PSC:** Creates a `google_compute_service_attachment` to expose this internal LB to other VPCs.

#### 4. Frontend Global LB (Chaining)
*   **File:** `frontend_lb_global.tf`
*   **Type:** Global External HTTP(S) Load Balancer
*   **Target:** **Internet NEG** pointing to the IP of the `backend_lb_global`.
*   **Concept:** Demonstrates LB-to-LB routing.

#### 5. Frontend Regional LB (Chaining)
*   **File:** `frontend_lb_regional.tf`
*   **Type:** Regional External HTTP(S) Load Balancer
*   **Target:** **Regional Internet NEG** pointing to the IP of the `backend_lb_regional`.
*   **Concept:** Demonstrates Regional LB-to-LB routing.

## Usage

1.  **Initialize Terraform:**
    ```bash
    terraform init
    ```

2.  **Review the Plan:**
    ```bash
    terraform plan
    ```

3.  **Apply Configuration:**
    ```bash
    terraform apply
    ```
    *Note: The Cloud Run deployment uses `local-exec` to build and push the Docker container. Ensure you have `gcloud` authenticated and Docker running.*

## Outputs

After applying, Terraform will output key IP addresses:
*   `regional_lb_ipv4_http`: IP of the Regional External LB.
*   `frontend_global_lb_ip`: IP of the Frontend Global LB (chained).
*   `frontend_regional_lb_ip`: IP of the Frontend Regional LB (chained).
*   `registry_name`: The Artifact Registry repository name.

## cleanup
To destroy the resources:
```bash
terraform destroy
```
