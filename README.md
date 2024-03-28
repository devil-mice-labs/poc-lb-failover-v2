# Application Load Balancers failover on Google Cloud (v2)

This repo contains infrastructure-as-code for the second iteration of my deep dive on Google [external Application Load Balancers](https://cloud.google.com/load-balancing/docs/https).

```
# TODO diagram
```

The [original article](https://medium.com/@olliefr/global-load-balancer-failover-62e98a0f1253) is still available as well.

## What's new?

On 14 March 2024, Google announced the general availability of [Certificate Manager](https://cloud.google.com/certificate-manager/docs/overview) certificates for Regional external Application Load Balancers -- [Cloud Load Balancing release notes](https://cloud.google.com/load-balancing/docs/release-notes#March_12_2024). Previously, the regional load balancers of that type could only use self-managed Compute Engine SSL certificates.

Armed with this knowledge I replaced semi-manual provisioning of a Let's Encrypt-issed SSL certificate with the Google-managed option. This not only reduced the complexity of the design, but also decreased the feature gap between the global and the regional variations of the external application load balancer.



## Pre-requisites

This is a multi-cloud deployment for Google Cloud and AWS. Here's what you need to get started:

* A Google Cloud project with billing enabled.
* The right permissions granted to you on the target Google Cloud project.
* A set of Google Cloud APIs enabled on the target Google Cloud project.
* An AWS account with Route 53 DNS zone configured.
* The right permissions to manage DNS records in the Route 53 target zone.

The following sections provide further information on the pre-requisites and the deployment process.

## Credentials for Google Cloud

To run Terraform I used [Application Default Credentials](https://cloud.google.com/docs/authentication/provide-credentials-adc) (ADC). 

Other common ways of authenticating Terraform to Google Cloud as described in the provider docs would also work.

## Permissions in Google Cloud

I deployed this design into a sandbox project where I have the basic `Owner` IAM role.

It should be possible to define a set of IAM predefined roles, instead.

## Enabled services in Google Cloud

This module does not enable any Google Cloud APIs on the target Google Cloud project. Service enablement is left as an exercise to the reader.

## Credentials for AWS

My choice of providing AWS credentials was via the environment variables:

* `AWS_ACCESS_KEY_ID`
* `AWS_SECRET_ACCESS_KEY`

Other common ways of authenticating Terraform to AWS as described in the provider docs would also work.

## Deployment

Pre-deployment configuration:

* Set up your credentials for Google Cloud SDK (`gcloud`).
* Set up your credentials for AWS.
* Configure the deployment by editing `terraform.tfvars`.

Deployment is a one-step process:

1. Apply Terraform configuration! This should deploy enough infra to enable the next step.

At this point you should have the service responding to requests via the global external ALB. You can verify that by opening the URL reported by `terraform output url -raw`


## Trigger failover

To trigger the failover, you can simulate global load balancer failure using the load balancer's feature called "fault injection". 

To do this, run Terraform `apply` with the input variable `simulate_failure` set to `true`:

```bash
terraform apply -var "simulate_failure=true"
```

After having done this, you should be able to see the DNS health probes failing in your AWS Route 53 console. After the predefined number of failures, the DNS entries will switch, and new requests are going to be served by the regional external ALB.

To reverse the effect, run the Terraform `apply` command again, with `simulate_failure` set to  `false`:

```bash
terraform apply -var "simulate_failure=false"
```

The following sections provide more details on different aspects of this deployment.

## DNS records

The DNS zone is hosted with Route 53.

The following DNS configuration is done by this deployment:

* Create records for DNS-based authorisation for provisioning Google-managed SSL certificates.
* Create a primary record for the global application load balancer's IP.
* Create a secondary record for the regional application load balancer's IP.
* Create a DNS health-check to enable automatic failover and recovery between the primary and secondary records.

As of the time of writing, this could not be done in Google Cloud DNS as it does not support health-checks for external load balancers.

## (Reference) Mapping between Google Cloud and Terraform resources

This section is a ready reckoner for a set of Terraform Google provider resources that have to do with Network Endpoint Groups (NEG) resources on Google Cloud.

`google_compute_global_network_endpoint_group` contains endpoints that reside *outside* of Google Cloud.

* [Terraform docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_network_endpoint_group)

  Endpoint type: `INTERNET_IP_PORT` or `INTERNET_FQDN_PORT` only.

* [Google REST API docs](https://cloud.google.com/compute/docs/reference/rest/v1/globalNetworkEndpointGroups)

`google_compute_region_network_endpoint_group` supports serverless products. This is what you use for regional *and* global load balancers' backends.

* [Terraform docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_network_endpoint_group)

  Endpoint type: `SERVERLESS` or `PRIVATE_SERVICE_CONNECT` only.

* [Google REST API docs](https://cloud.google.com/compute/docs/reference/rest/v1/regionNetworkEndpointGroups)

`google_compute_network_endpoint_group` are *zonal* resources.

* [Terraform docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_endpoint_group)

  Endpoint type: `GCE_VM_IP`, `GCE_VM_IP_PORT`, or `NON_GCP_PRIVATE_IP_PORT` only.

* [Google REST API docs](https://cloud.google.com/compute/docs/reference/rest/v1/networkEndpointGroups)


## Limitations

As of the time of writing:

* Regional application load balancers have a severe [limit on QPS for Cloud Run backends](https://cloud.google.com/load-balancing/docs/negs/serverless-neg-concepts#limitations-reg). The current design can be easily adapted to route to other kinds of supported back-end though.

* Regional application load balancers do not support backend buckets. While not a feature of the current design, this limitation is quite annoying.

* Google Cloud DNS does not support health checks for external application load balancers. If that changes, Route 53 can be replaced with Google Cloud DNS in the next iteration of design.
