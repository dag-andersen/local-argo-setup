# local-argo-setup

## how to start

Install tools:
```bash
make install-tools
```

Create a credentials file here: `creds/repo-creds.yml`

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

Run

```bash
make everything path-to-repo=<path-to-repo>
```

when everything is synced and happy

then run 

```bash
make update
```

Good luck 
