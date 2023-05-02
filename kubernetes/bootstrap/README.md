```sh
sops --decrypt sops-age-secret.sops.yaml | kubectl apply -f -
sops --decrypt deploy-key.sops.yaml | kubectl apply -f -
```