# Hop web on GCP 

## Launch IAP with VM

After deploying the VM with the Terraform code, you need to redirect a local port
to the VM using the [Identity Aware Proxy](https://cloud.google.com/iap). 
Launch this command and leave it running:

```shell
gcloud compute start-iap-tunnel hop-vm 8080 --local-host-port=localhost:8080 --zone=<YOUR ZONE>
```

Then go to `localhost:8080` in your web browser to access the main UI of Hop.