# local-argo-setup

## How to start

1. Install tools:
   ```bash
   make install-tools
   ```

2. Create a credentials file here: `creds/repo-creds.yml`
   ```yml
   apiVersion: v1
   kind: Secret
   metadata:
     name: private-repo-creds
     namespace: argocd
     labels:
       argocd.argoproj.io/secret-type: repo-creds
   stringData:
     type: git
     url: https://github.com/<org-or-username>
     username: <username>
     password: <token>
   ```

3. Start the cluster
   ```bash
   make start
   ```

4. Now apply your ArgoCD Applications. Only you know what should be applied.

5. Wait until apps are synced and healthy.

6. Replace all the ingress addresses:
   ```bash
    make replace-all-hostnames path-to-root=<repo-parent> path-to-repo=<path-to-repo> domain=<the-domain-you-want-replaced>
    ```
    example: `make replace-all-hostnames path-to-root=".." path-to-repo="cloud-infra-deployment" domain="dagandersen.com"` if you repo looks like this
    ```
    ├── this repo
    └── cloud-infra-deployment
        ├── yaml1.yml
        ├── yaml2.yml
        └── yaml3.yml
    ```

7. make your changes to your gitops-synced-repo and run
   ```bash
   make update path-to-root=<repo-parent> path-to-repo=<path-to-repo>
   ```

8. Done. Your local changes should now be applied to the cluster. 