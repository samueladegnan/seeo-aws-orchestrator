---
title: SEEO
layout: default
permalink: /
---

[![SEEO CI](https://github.com/samueladegnan/seeo-aws-orchestrator/actions/workflows/ci.yml/badge.svg)](https://github.com/samueladegnan/seeo-aws-orchestrator/actions/workflows/ci.yml)
[![Python 3.11](https://img.shields.io/badge/python-3.11-blue.svg)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/samueladegnan/seeo-aws-orchestrator/blob/main/LICENSE)

<div class="hero" markdown="1">

<p class="hero__title">Secure, self-service AWS environments in seconds</p>

<p class="hero__lead">SEEO automates the deployment of secure, TTL-bound AWS infrastructure through a REST API and web dashboard. Built for teams that need temporary cloud resources without the sprawl.</p>

</div>

## What It Is

SEEO is a production-oriented, full-stack internal DevOps tool. It gives teams a self-service way to request temporary EC2 environments through a REST API or web dashboard, with every resource automatically torn down once its TTL expires.

## How It Works

<div class="steps" markdown="1">

<div class="step" markdown="1">

### 1. Request

A developer requests an environment through the **FastAPI backend** or the web dashboard, specifying a project name and TTL.

</div>

<div class="step" markdown="1">

### 2. Provision

SEEO stores environment metadata in **DynamoDB** and provisions a hardened **EC2 instance** with an attached **EBS volume**.

</div>

<div class="step" markdown="1">

### 3. Authenticate

The instance assumes an **IAM role** to fetch runtime credentials from **AWS Secrets Manager** — no credentials are baked into code or user-data.

</div>

<div class="step" markdown="1">

### 4. Expire

A background **TTL service** continuously scans for expired environments and terminates them automatically.

</div>

</div>

## Why It Matters

- **Reduces infrastructure sprawl** by ensuring every environment has a strict expiration time.
- **Proves secure orchestration** through least-privilege IAM roles and zero-hardcoded secrets.
- **Demonstrates full-stack ownership** from FastAPI backend and Terraform infrastructure to a responsive vanilla-JS dashboard.

## Key Features

<div class="feature-grid" markdown="1">

<div class="feature-card" markdown="1">

#### Self-Service Environments

Request temporary EC2 environments through a REST API or a responsive web dashboard.

</div>

<div class="feature-card" markdown="1">

#### Hardened EC2 + EBS

Each request provisions a hardened EC2 instance with an attached EBS volume automatically.

</div>

<div class="feature-card" markdown="1">

#### Zero-Hardcoded Secrets

Runtime credentials are fetched from AWS Secrets Manager via IAM roles.

</div>

<div class="feature-card" markdown="1">

#### TTL Lifecycle Automation

Expired environments are torn down automatically by the background TTL service.

</div>

<div class="feature-card" markdown="1">

#### Infrastructure as Code

All AWS resources are defined and managed with Terraform.

</div>

<div class="feature-card" markdown="1">

#### Containerized Backend

FastAPI backend ships in a Docker container for consistent deployment.

</div>

</div>

## Live Demo

Try the dashboard right in your browser — no AWS account or backend setup required — on the [Interactive Live Demo](./demo/).

You can also run SEEO locally; see the [README](https://github.com/samueladegnan/seeo-aws-orchestrator#readme) for setup instructions.

## Explore Further

- [Architecture Deep Dive](./architecture/) — data flow, component diagram, and security highlights.
- [API Documentation](./api/) — authentication, endpoints, and dashboard details.

## Technology Stack

| Layer                | Technology                                   |
|----------------------|----------------------------------------------|
| API / Business Logic | Python 3.11, FastAPI, Pydantic v2            |
| Cloud Orchestration  | boto3 (EC2, EBS, Secrets Manager, DynamoDB) |
| State Store          | DynamoDB                                     |
| Secrets Management   | AWS Secrets Manager                          |
| Infrastructure       | Terraform (AWS provider)                     |
| Dashboard            | Vanilla JS + CSS served by FastAPI/Jinja2    |
| Container            | Docker                                       |

## About the Author

Built by [Samuel Degnan](https://samueladegnan.github.io/) as a portfolio project demonstrating secure cloud engineering, infrastructure automation, and full-stack DevOps.
