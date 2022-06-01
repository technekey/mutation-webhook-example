This repo contains a super basic example of validation webhook in kubernetes.

```
#build the image from the directory with Dockerfile
docker build -t mutate-prod-deployment-replicas:latest .
#tag the image
docker tag mutate-prod-deployment-replicas technekey/mutate-prod-deployment-replicas:latest

#push to the repo
docker push technekey/mutate-prod-deployment-replicas:latest
```
