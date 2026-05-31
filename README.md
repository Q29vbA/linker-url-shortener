# Linker - URL Shortener

A containerized URL shortener deployed via GitOps on Kubernetes, part of my SailPoint take-home exercise

## 1. Run Locally
### With Docker
Build and run the container locally, overriding the `BASE_URL` environment variable:

```bash
docker build -t linker:local .
docker run --rm -p 8080:8080 -e BASE_URL=http://localhost:8080 linker:local
```

The application will be available on http://localhost:8080

### With Helm (Bonus)
You can also install it directly to your cluster without ArgoCD. Just set your desired values (like `image.tag` or `baseUrl`) in `values.yaml` and run:
```bash
helm install linker charts/linker/
```

## 2. Bootstrap on Local Cluster (Minikube)
I used Minikube for this setup. A `kind` installation should be very similar, though you might need slightly different commands (for example, to enable the ingress controller).

Ensure your Minikube cluster is running:

```bash
minikube start
# make sure you have the NGINX Ingress addon enabled (or disable ingress in helm chart)
minikube addons enable ingress
```

## 3. Install and Configure ArgoCD
Install ArgoCD and apply the declarative Application manifest:

```bash
kubectl create namespace argocd

# Installs current stable version, which can change. In a real production environment, it's best practice to use a pinned version to avoid unexpected upstream breakages
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD server
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=120s
```

*(Optional)* Edit the ArgoCD Application manifest at `argocd/application.yaml` under `.spec.source.helm.values` to override chart values, like `baseUrl`.

```bash
# The Application is configured with autosync, so it will start deploying resources right away
kubectl apply -f argocd/application.yaml
```

## 4. Verify End-to-End

### Verify deployment functionality
After deployment, we will route traffic through the NGINX Ingress Controller to access the application from outside the cluster.

Port-forward the Ingress controller:

```bash
# Use --address 0.0.0.0 to make application be reachable from remote
# If you are running this on a remote machine (like EC2), use it with caution and proper firewall rules!
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 80:80
```
(*Leave this running in your terminal!*)

By default, the ingress host is derived from `BASE_URL`. In these steps, I assume you're using the hardcoded baseUrl in `argocd/application.yaml` / the default value in helm chart: `linker.local`.

In a separate terminal, edit your `/etc/hosts` file to resolve the ingress hostname to your localhost:

```bash
# Use 127.0.0.1 when running locally, or your machine's IP if accessing from remote
echo "<IP> linker.local" | sudo tee -a /etc/hosts
```

Test the routing and endpoints. Since `ingress.host` is dynamically derived from `BASE_URL` inside the chart template, shortened URLs will point to the correct host automatically:

```bash
# Test URL shortening
curl -X POST http://linker.local/shorten -H "Content-Type: application/json" -d '{"url": "https://sailpoint.com"}'
# Test shortened link
curl -L http://linker.local/<slug returned from POST>
# /stats endpoint
curl http://linker.local/stats
# /health endpoint
curl http://linker.local/health
```

### Verify CI workflow
You can trigger the workflow manually from the GitHub Actions tab, or run it locally using the [act tool](https://github.com/nektos/act):
```bash
act --workflows ".github/workflows/ci.yml" -s GITHUB_TOKEN --actor <your_github_username>
```
*Make sure to provide a valid PAT as the `GITHUB_TOKEN` for a successful login and push.*

## Production Readiness & Trade-offs

To align with the assignment's focus on clarity over completeness, I scoped this implementation for a local environment. For a true production deployment, I would address the following:

* **TLS & Secret Management:** This local setup runs over plain HTTP. In production, I would deploy `cert-manager` with a Let's Encrypt ClusterIssuer, or use an ALB Ingress Controller with AWS ACM, to automate certificate rotation entirely outside the GitOps sync loop.
* **CI Pipeline Architecture:** I intentionally skipped cross-architecture builds to keep the pipeline simple, fast, and avoid filling up the container registry.
* **Continuous Deployment (Image Updates):** For simplicity here, the Argo Application tracks the chart in `main` tag. In real production, I would point to an immutable tag; Regarding image tag, I would use **ArgoCD Image Updater** to automatically detect new images in GHCR and write the updated tag in git, instead of manual update
* **Probes** Both Liveness and Readiness probes currently hit the single `/health` endpoint. I configured the Readiness probe to fail faster than Liveness, pulling the pod from the Service endpoints before triggering a hard restart (giving it a chance to recover in a case, for example, of a time-consuming request). Ideally, the code should expose distinct `/health/live` and `/health/ready` endpoints.
* **Scaling & High Availability:** The current app uses a Python dictionary for in-memory storage, meaning state cannot be shared across replicas. Once the app is made stateless by integrating a centralized datastore (like **Redis**, which is in-memory but shared across all pods and supports persistence), I would implement a Horizontal Pod Autoscaler (**HPA**) and a PodDisruptionBudget (**PDB**).
* **Security & Hardening:** I would add a **NetworkPolicy** to restrict internal endpoints and egress traffic. Additionally, I would implement **linting, validation, and security scans** in the CI pipeline. Finally, the image should be private, requiring an **imagePullSecret** injected securely (e.g., via External Secrets Operator paired with external secret store, such as Vault or AWS Secrets Manager).
