# Kubernetes logging: To infinity and beyond

## Abstract

Managing change in widely-adopted open source projects has unique challenges. Modernizing core functionalities is like changing the engine of a moving car—how do you ensure a smooth ride for users?
This session explores how we modernized the Logging-operator (a CNCF sandbox project). We'll dive into how we:

- Transitioned from Fluentd+Fluentbit to OpenTelemetry collectors
- Implemented true multi-tenancy with the Telemetry Controller
- Ensured seamless adoption for users including major adopters like Rancher

The presentation includes technical demonstrations and architectural insights for Kubernetes operators, platform engineers, and open-source maintainers, so you’ll learn:

- How to gradually adopt a modern logging architecture using OpenTelemetry collectors in an existing infrastructure without disrupting your current setups
- Strategies for evolving production-grade Kubernetes operators without disrupting users

## Presented at

- April 24, 2025 @ **KCD Budapest**
- June 5, 2025 @ **KCD Bratislava**
