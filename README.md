<img width="541" height="304" alt="Screenshot 2026-10-19 at 1 31 58 AM" src="https://github.com/user-attachments/assets/73262f93-f575-412d-aff4-fc088fce5187" />
<img width="523" height="206" alt="Screenshot 2026-10-19 at 1 31 47 AM" src="https://github.com/user-attachments/assets/8da71243-c6f5-48ef-a2b0-76af2a196953" />

Project Context: Microserviceset Platform (paste into any AI session)
Purpose: give an AI agent the full picture of this project in one read, so it can help without re-explaining. Owner: Aditya (DevOps/SRE learner, building an industry-grade setup as practice). Last updated: 2026-10-19. Secret VALUES are never stored here; only names and locations.


0. How to help me (working preferences)
Give ONE small step at a time. Wait for my output/feedback before the next step.
Explain WHAT and WHY briefly for each step. Be short and precise.
Prefer GUI (GitHub / GCP console / Argo CD UI) for GUI-able resources; CLI only where CLI is natural (git, terraform, kubectl, helm).
Always follow industry-grade practice (PR flow, GitOps, least privilege, pinned versions, no secrets in git).
My machine: macOS, zsh (watch zsh quirks: no word-splitting of $VAR commands → use functions; $VAR:s is a modifier → use ${VAR}:scan).
I copy-paste commands, so give complete, copy-pasteable blocks with real paths.


1. Big picture (one diagram)
                         ┌──────────────────────── GitHub org: Microserviceset ────────────────────────┐

 Developer (Mac)         │                                                                             │

 feature branch ──push──▶│  APP REPO: rabbitmq-microservice-playground (public, monorepo, 6 services)  │

                         │    PR ─▶ ci.yml ─▶ detect-changes ─▶ security.yml per changed service       │

                         │            │            ├─ Trivy (GitHub-hosted runner)                     │

                         │            │            └─ SonarQube scan ──────────────┐ (in-cluster ARC)  │

                         │            └─▶ ci-success (required check) ─▶ squash-merge to main          │

                         │    tag vX.Y.Z ─▶ release.yml ─▶ build multi-arch images ─┐                   │

                         │                                                          │ WIF (keyless)     │

                         │  INFRA REPO: Infra (public)                              │                   │

                         │    PR ─▶ terraform.yml: plan (terraform-plan SA)         │                   │

                         │    merge ─▶ apply (terraform-apply SA, needs approval)   │                   │

                         │    helm/ + argocd/ + platform/  (GitOps source of truth) │                   │

                         └──────────────────────────────────────────────────────────┼───────────────────┘

                                                                                    ▼

 ┌─────────────────────────── GCP project aditest-511508 (asia-south1) ────────────────────────────────┐

 │  Artifact Registry: asia-south1-docker.pkg.dev/aditest-511508/microservices/<service>:<version>      │

 │  GCS bucket: aditest-511508-tfstate (Terraform state, versioned)                                     │

 │  Workload Identity Federation pool "github" (providers: github-oidc, github-infra)                    │

 │  VPC aditest-vpc ─ GKE cluster aditest-gke (zonal asia-south1-a, 1 node e2-standard-4)               │

 │     ├─ argocd       : Argo CD (pulls Infra repo, deploys everything below)                           │

 │     ├─ staging      : taskmanager app (7 deployments + 3 Postgres + RabbitMQ)                        │

 │     ├─ production   : empty (planned)                                                                │

 │     ├─ sonarqube    : SonarQube Community + its Postgres                                             │

 │     ├─ arc-systems  : ARC controller + listener                                                       │

 │     └─ arc-runners  : ephemeral GitHub Actions runner pods (dind)                                    │

 └──────────────────────────────────────────────────────────────────────────────────────────────────────┘


2. Identifiers (reference)
Thing
Value
GitHub org
Microserviceset (org ID 343192227)
App repo
Microserviceset/rabbitmq-microservice-playground (public). Originally cloned from arjun-aryal/rabbitmq-microservice-playground (remote upstream)
Infra repo
Microserviceset/Infra (public, repo ID 1421793671)
GCP project
aditest-511508, number 464954553497
Region / zone
asia-south1 / asia-south1-a
Artifact Registry (used)
asia-south1-docker.pkg.dev/aditest-511508/microservices
Artifact Registry (unused, Terraform-made)
.../aditest-511508/apps
Mirror registry
ghcr.io/microserviceset/<service>
GKE cluster
aditest-gke (zonal, private nodes, PUBLIC control-plane endpoint, master CIDR 172.16.0.0/28, Secret Manager add-on enabled, node pool default-pool 1× e2-standard-4)
Network
VPC aditest-vpc, subnet aditest-subnet-mum 10.10.0.0/20, Cloud Router + NAT, firewalls allow-internal, allow-ssh-iap, VM test-vm
Terraform state
gs://aditest-511508-tfstate/core/default.tfstate (object versioning ON)
Local paths
/Users/aditya/Desktop/Ecomm/msc/rabbitmq-microservice-playground, /Users/aditya/Desktop/Ecomm/msc/Infra
Old Terraform folder
.../msc/Terraform-GCP-OLD-DO-NOT-USE (migrated; has unused platform/, edge/ stacks never applied)



3. The application (taskmanager)
 Browser ─▶ web-ui (:3000, Vite static) ─▶ api-gateway (:4000)

                                             ├─▶ auth-service (:4001, Node) ─▶ postgres-auth

                                             ├─▶ task-service (:4002, Node) ─▶ postgres-task

                                             │        └─publishes─▶ RabbitMQ exchange "task_events"

                                             └─▶ reporting-service (:4004, Django/gunicorn) ─▶ postgres-reporting

 RabbitMQ "task_events" ─▶ notification-service (consumer, DLX "task_events.dlx")

                       └─▶ reporting-consumer (same image as reporting-service, cmd: manage.py consume_events)

JWT shared secret between auth-service and task-service (JWT_SECRET).
Known issue: web-ui bakes VITE_API_BASE_URL at build time (default http://localhost:4000), so in-cluster it only works with port-forwarding. Needs fix (relative /api path via Ingress, or runtime config).
Local dev: docker-compose.yml + .env.example (placeholders only). Load-test outputs are git-ignored.


4. Branching, commits, versioning (both repos)
feature/<svc>-<desc> | fix/... | ci/... | chore/... | docs/... | hotfix/...

        │

        └─ PR ─▶ checks ─▶ "Squash and merge" (only merge method allowed) ─▶ main (protected)

                                                                               │

                                                     tag vX.Y.Z (annotated) ◀──┘  (app repo only)

Trunk-based: main always deployable; short-lived branches; branches auto-deleted after merge.
Conventional Commits for commits AND PR titles (PR title becomes the squash commit): feat(auth-service): ..., fix(...), ci: ..., chore: ....
SemVer tags vMAJOR.MINOR.PATCH; -rc.N suffix planned for staging candidates.
Released so far: v0.1.0, v0.1.1, v0.1.2 (staging runs 0.1.2).
Local git config: pull.ff only; gh repo set-default set per repo.
GitHub Free plan ⇒ rulesets/environment protections are only enforced because both repos are public.
Rulesets
Repo
Ruleset
Rules
App
protect-main (default branch)
PR required (0 approvals, solo), conversation resolution, block force-push & deletion, required status check ci-success (GitHub Actions app id 15368)
App
protect-release-tags (v*)
restrict deletions, restrict updates, block force pushes
Infra
protect-main
PR required (0 approvals), block force-push & deletion
Infra
Environment production
required reviewer = Adityacom7, deployment branch main only, admin bypass OFF



5. App repo CI/CD flows
5.1 PR / merge to main — ci.yml
pull_request or push(main)

  └─ detect-changes  (dorny/paths-filter@v3; a change to ci.yml or security.yml ⇒ all services)

       └─ security (matrix: changed services)  ── uses: ./.github/workflows/security.yml, secrets: inherit

            ├─ job "scan"      [ubuntu-latest]

            │    ├─ Trivy fs  (vuln,secret,misconfig; HIGH,CRITICAL)   docker image aquasec/trivy:0.58.1 (pinned)

            │    ├─ docker build <svc>:scan

            │    ├─ Trivy image (HIGH,CRITICAL, --ignore-unfixed)

            │    └─ upload SARIF ─▶ GitHub Security tab (categories trivy-fs-<svc>, trivy-image-<svc>)

            └─ job "sonarqube" [runs-on: arc-runner-set  ⇒ pod inside GKE]

                 └─ SonarSource/sonarqube-scan-action@v5

                      projectKey taskmanager_<svc>, projectBaseDir <svc>, qualitygate.wait=true

                      SONAR_HOST_URL (var) = http://sonarqube-sonarqube.sonarqube.svc.cluster.local:9000

                      SONAR_TOKEN (secret)

  └─ ci-success  (always runs; fails if any needed job failed/cancelled) ◀── the ONLY required check

Mode: report-only (blocking: false ⇒ Trivy exit-code 0, Sonar continue-on-error). Flip to true to block merges.
Images built in CI are thrown away; nothing is pushed on PR/merge.
No unit tests exist in any service yet (no test scripts / test files).
5.2 Release — release.yml
git tag -a vX.Y.Z && git push origin vX.Y.Z

  └─ on push tags 'v*.*.*' ─▶ matrix: all 6 services

       ├─ setup-qemu + buildx (platforms linux/amd64,linux/arm64)

       ├─ google-github-actions/auth@v2 (WIF provider github-oidc ─▶ SA github-release, access_token)

       ├─ docker login to Artifact Registry (oauth2accesstoken) + GHCR (GITHUB_TOKEN)

       ├─ docker/metadata-action: tags {{version}} (e.g. 0.1.2), {{major}}.{{minor}}, sha-<short>

       └─ build-push-action ─▶ AR microservices/<svc> AND ghcr.io/microserviceset/<svc>  (gha cache per svc)

  GitHub Release page/notes: created MANUALLY (gh release create --generate-notes, or GUI)

Known issue: web-ui arm64 build segfaulted under QEMU (npm install). Fix: FROM --platform=$BUILDPLATFORM node:... AS builder in web-ui/Dockerfile (static output is arch-independent). Verify it is committed.
App repo variables: GCP_PROJECT_ID, GCP_REGION, GCP_AR_REPO, GCP_WIF_PROVIDER (…/providers/github-oidc), GCP_SERVICE_ACCOUNT (github-release@…), SONAR_HOST_URL. Secret: SONAR_TOKEN.
Actions setting: fork PRs from external contributors require approval (protects self-hosted runners).


6. Infra repo
6.1 Layout
Infra/

├── .github/workflows/terraform.yml

├── terraform/core/          backend.tf (gcs, prefix core) · main.tf (VPC, NAT, FW, VM, APIs, gke-nodes SA, AR "apps")

│                            gke.tf (cluster + node pool, secret_manager_config enabled=true)

│                            registry.tf (import + AR "microservices") · k8s.tf (kubernetes provider, namespaces staging/production)

│                            providers: google 6.50.0, kubernetes >=2.36 <4.0 (lock file has darwin_arm64 + linux_amd64)

├── helm/taskmanager/        Chart.yaml · values.yaml · values-staging.yaml (image.tag "0.1.2", replicas 1)

│                            templates/: _helpers.tpl, services.yaml (generic Deployment+Service loop),

│                                        postgres.yaml (3 StatefulSets), rabbitmq.yaml (StatefulSet; readiness timeout 10s)

├── argocd/apps/             taskmanager-staging · sonarqube · sonarqube-postgres · arc-controller · arc-runner-set

├── argocd/repos/            arc-charts.yaml (OCI helm repo ghcr.io/actions/actions-runner-controller-charts, enableOCI)

└── platform/sonarqube/      postgres.yaml (Postgres for SonarQube)
6.2 Terraform flow — terraform.yml
PR touching terraform/**  ──▶ job terraform-plan

     auth: WIF provider github-infra ─▶ SA terraform-plan (read-only)

     fmt -check ─▶ init ─▶ validate ─▶ plan ─▶ plan posted as PR comment

merge to main  ──▶ job terraform-apply  (environment: production)

     ⏸ waits for manual approval (required reviewer)

     auth: WIF ─▶ SA terraform-apply ─▶ init ─▶ apply -auto-approve

concurrency group "terraform-core" (no parallel applies). Terraform version pinned 1.14.5.

Humans do not apply from laptops (local plan only). State in GCS.

Infra repo variables: GCP_WIF_PROVIDER (…/providers/github-infra), TF_PLAN_SA, TF_APPLY_SA.
6.3 GitOps deploy flow (Argo CD)
Change helm/ or values-*.yaml via PR ─▶ merge to main

   └─ Argo CD (polls ~3 min, or click Refresh) ─▶ renders helm chart ─▶ applies to namespace

      syncPolicy automated + prune + selfHeal  (manual cluster edits get reverted ⇒ fix via git)

Application manifests are in git but were registered ONCE manually: kubectl apply -f argocd/apps/<app>.yaml

(planned: app-of-apps so Argo picks up new Application files itself)
6.4 Planned promotion flow (not built yet)
tag vX.Y.Z ─▶ images in AR ─▶ PR: values-staging.yaml tag ─▶ Argo ─▶ staging ─▶ test

   ─▶ PR: values-production.yaml tag (review = approval) ─▶ Argo ─▶ production

Build once, promote the same image. Never deploy :latest to production.


7. Identity & access (keyless, Workload Identity Federation)
GitHub job ─(OIDC token, id-token: write)─▶ GATE 1: pool "github" provider (verifies signature + attribute condition,

                                                    maps claims ─▶ attributes)

                                         ─▶ GATE 2: service account IAM (Workload Identity User grant must match attributes)

                                         ─▶ 1-hour GCP token ─▶ job acts as the SA

Provider
Attribute condition
Mappings
Used by
github-oidc
assertion.repository=='Microserviceset/rabbitmq-microservice-playground' && assertion.ref.startsWith('refs/tags/v')
google.subject, attribute.repository, attribute.ref
release.yml
github-infra
assertion.repository == 'Microserviceset/Infra'
google.subject, attribute.repository, attribute.ref, attribute.environment = assertion.sub.endsWith(':environment:production') ? 'production' : 'none'
terraform.yml


Service account
Who can impersonate (WIU principal)
Roles
github-release@
principalSet …/attribute.repository/Microserviceset/rabbitmq-microservice-playground
Artifact Registry Writer on repo microservices only
terraform-plan@
principalSet …/attribute.repository/Microserviceset/Infra
Viewer, Security Reviewer (project); Storage Object Admin on state bucket (for lock)
terraform-apply@
principalSet …/attribute.environment/production
Editor, Project IAM Admin, Service Account Admin, IAM Workload Identity Pool Admin
gke-nodes@
(node SA, Terraform-managed)
logging/monitoring roles, artifactregistry.reader (nodes pull images)
aditests@
unknown purpose (to review/disable)
?


Lesson learned: this org's GitHub OIDC sub is ID-based: repo:Microserviceset@343192227/Infra@1421793671:pull_request. Granting on full-subject strings failed; attribute-based principalSets work. Full incident note exists in Claude Docs ("Incident Note: Terraform CI GCP Auth Failure").
Bootstrap APIs enabled manually: Cloud Resource Manager, IAM, IAM Credentials, STS, Artifact Registry (others via Terraform google_project_service).
Bootstrap (manual, should later move to terraform/bootstrap): state bucket, CI SAs, WIF pool/providers, bootstrap APIs.


8. Cluster contents
Namespace
What
How deployed
argocd
Argo CD (stable manifest, server-side apply). UI: kubectl port-forward svc/argocd-server -n argocd 8080:443 → https://localhost:8080 (admin password changed; initial secret deleted)
kubectl (bootstrap)
staging
taskmanager: api-gateway, auth-service, task-service, notification-service, reporting-service, reporting-consumer, web-ui + postgres-auth/task/reporting + rabbitmq
Argo app taskmanager-staging (helm/taskmanager + values-staging.yaml)
production
empty
Terraform (namespace only)
sonarqube
SonarQube Community, chart 2026.5.1002 (app 2026.5.2), external DB via jdbcOverwrite; sonarqube-postgres StatefulSet. UI: port-forward svc/sonarqube-sonarqube 9000
Argo apps sonarqube + sonarqube-postgres
arc-systems
ARC controller gha-runner-scale-set-controller 0.15.0 + listener
Argo app arc-controller
arc-runners
runner scale set arc-runner-set: org-level, runner group arc-internal (only app repo, public repos allowed), min 0 / max 2, containerMode dind
Argo app arc-runner-set

ARC flow
GitHub job (runs-on: arc-runner-set) ─▶ listener pod (arc-systems, long-poll via GitHub App) ─▶ controller

   ─▶ creates ephemeral runner pod in arc-runners (runner + dind) ─▶ job runs in-cluster ─▶ pod deleted

GitHub App "microserviceset-arc": App ID 5371701, Installation ID 172793678, permission Org ▸ Self-hosted runners: R/W.

Purpose: in-cluster jobs reach internal services (SonarQube) without exposing them publicly.
Secrets inventory (created manually with kubectl; never in git)
Namespace / Secret
Keys
staging/taskmanager-secrets
POSTGRES_PASSWORD, JWT_SECRET, DJANGO_SECRET_KEY
sonarqube/sonarqube-db
password
sonarqube/sonarqube-monitoring
passcode
arc-runners/arc-github-app
github_app_id, github_app_installation_id, github_app_private_key
GitHub app repo secret
SONAR_TOKEN (SonarQube global analysis token github-ci)


Planned: move to GCP Secret Manager + External Secrets Operator.


9. Machine-readable dependency graph (edges)
developer        -[opens PR]->            app_repo

developer        -[pushes tag v*]->       app_repo

app_repo         -[PR/push main triggers]-> ci_yml

ci_yml           -[calls per changed svc]-> security_yml

security_yml     -[runs on github-hosted]-> trivy_scan

security_yml     -[runs on arc-runner-set]-> sonarqube_scan

sonarqube_scan   -[HTTP internal]->       sonarqube (ns sonarqube)

sonarqube        -[JDBC]->                sonarqube_postgres

trivy_scan       -[SARIF]->               github_security_tab

ci_yml           -[gate]->                ci_success -[required by]-> app_ruleset_protect_main

app_repo         -[tag triggers]->        release_yml

release_yml      -[WIF github-oidc]->     sa_github_release

sa_github_release-[writes]->              artifact_registry_microservices

release_yml      -[GITHUB_TOKEN]->        ghcr

gke_nodes_sa     -[reads]->               artifact_registry_microservices

infra_repo       -[PR triggers]->         terraform_yml.plan -[WIF github-infra]-> sa_terraform_plan

infra_repo       -[merge triggers]->      terraform_yml.apply -[env production approval]-> sa_terraform_apply

terraform        -[state]->               gcs_tfstate_bucket

terraform        -[manages]->             vpc, nat, firewalls, test_vm, gke_cluster, node_pool, ar_apps, ar_microservices, ns_staging, ns_production

argocd           -[watches main]->        infra_repo

argocd           -[deploys]->             taskmanager_staging, sonarqube, sonarqube_postgres, arc_controller, arc_runner_set

taskmanager_staging -[pulls images tag from values-staging.yaml]-> artifact_registry_microservices

arc_listener     -[GitHub App auth]->     github_org

arc_controller   -[creates]->             runner_pods (ns arc-runners)


10. Gotchas already solved (don't repeat)
Symptom
Cause
Fix
Direct push to main succeeded
Private repo on Free plan ⇒ rulesets not enforced
Made repos public
Required check never runs on unrelated PRs
Path-filtered workflow as required check
Single always-running ci-success gate
getAccessToken denied in Terraform CI
ID-based OIDC subject didn't match subject-string grant
Attribute-based principalSets + attribute.environment mapping
SERVICE_DISABLED cloudresourcemanager
Bootstrap API off
Enabled manually
Apply ran without approval
Required reviewer not saved; admin bypass on
Re-saved env rule; bypass off; verified via gh api …/environments/production
Duplicate required providers
Two required_providers blocks
Merged into main.tf
kubectl/get-credentials hang
Missing gke-gcloud-auth-plugin on PATH
PATH += /opt/homebrew/share/google-cloud-sdk/bin
web-ui ImagePullBackOff
web-ui:0.1.2 not pushed (arm64 QEMU segfault)
BUILDPLATFORM builder stage; re-run release; delete pod
rabbitmq 0/1 Ready
readiness probe 1s timeout too short
timeoutSeconds 10, failureThreshold 6
Empty PR merged / file missing
Step skipped before commit
Always git log -1 --stat / check "Files changed" before merging
ARC test workflow invalid
YAML plain scalar containing : 
Use `run:



11. Open items / roadmap
Production: values-production.yaml, Argo app taskmanager-production, promotion via PR.
Expose apps: Ingress + TLS + real URL; fix web-ui build-time API URL.
Secrets: GCP Secret Manager + External Secrets Operator (rotate SONAR_TOKEN, Argo admin, App key).
Security pipeline: conditional unit-test stage (+ coverage to Sonar); Trivy gate + SBOM (CycloneDX) + cosign signing in release.yml; switch to blocking mode; Dependabot/Renovate; registry/in-cluster rescans (Trivy Operator).
Fix existing findings, e.g. auth-service proxy-addr 2.0.7→2.0.8 (CRITICAL), Dockerfiles missing USER (run as root).
Terraform: terraform/bootstrap for manual resources; import github-release SA/WIF; decide on unused AR apps; nightly drift detection.
Argo: app-of-apps; add CODEOWNERS + PR template; immutable image tags (drop {{major}}.{{minor}} tag).
Housekeeping: review/disable aditests SA; secure the GitHub App .pem; delete old Terraform-GCP folder; upstream remote kept for original author's updates.

