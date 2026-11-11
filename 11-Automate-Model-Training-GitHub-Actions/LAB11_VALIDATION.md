# Lab 11 revision validation — 11 November 2026

- New Bicep entry point compiles with Bicep 0.46.1.
- Guided setup PowerShell syntax parsed successfully.
- Guided setup was exercised through -PreviewOnly against teaching subscription 42848f6c-f0f7-4143-b9d3-76441ceeda99. GitHub administrator check, immutable OIDC subject construction, parameter-file creation and Azure what-if all succeeded. Azure reported 10 resources to create, including course-cpu, managed identity, federation and workspace-scoped training role.
- No resources were deployed by this preview and no GitHub secrets were changed.
- Training Python and workflow YAML parse; git diff whitespace checks pass.
- The student guide and embedded HTML index were rebuilt from the revised Markdown.
- The existing workflow's earlier cloud-training success is recorded in the root validation reports. The new managed-identity provisioning path has NOT yet been deployed and trained end to end. Deployment, quota availability, data upload, identity propagation and GitHub sign-in must still be verified live before claiming a fully validated client release.
- A local SQLite tracking check exposed an incompatible SQLAlchemy installation in the existing local virtual environment. The follow-up uses MLflow's local file tracking backend; this does not change the Azure job environment, which is pinned in train-job.yml.
- Local training completed on all 112,650 rows with max_iter=2: metrics, figures, feature importance, metrics.json and the MLflow model were saved/logged successfully. This is a smoke check, not a model-quality benchmark.
