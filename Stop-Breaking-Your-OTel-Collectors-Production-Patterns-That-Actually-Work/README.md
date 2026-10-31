# Stop Breaking Your OTel Collectors: Production Patterns That Actually Work

## Abstract

After deploying OTel Collector comes the real-world challenges: filtering noisy telemetry, routing data to multiple destinations, managing resource consumption, and keeping your pipeline reliable as traffic scales.
From basic collector deployments to production-grade, this talk shows practical patterns to solve common problems, like:

- Using tail sampling to reduce costs without losing critical traces.
- Enriching spans with Kubernetes metadata for better debugging.
- Implementing batch processing per output to handle traffic bursts efficiently.

You'll see examples for how to design collector architectures that match your infrastructure (Gateway mode, DaemonSets), configure health checks and self-monitoring, and structure your processor pipelines for performance and maintainability.
We'll cover real operational challenges: graceful shutdown to avoid data loss, memory tuning to prevent OOMKills, and strategies for testing collector configs before they hit production.

## Presented at

- May 21, 2026 @ [KCD Czech & Slovak - Prague](https://community2.cncf.io/events/details/cncf-kcd-czech-slovak-presents-kcd-czech-amp-slovak-prague-2026/)
- October 30, 2026 @ [KCD Budapest](https://kcdbudapest.hu/)
