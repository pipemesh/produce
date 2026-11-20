# pipemesh/produce

Emits an entry of the dispatching Pipemesh job's output manifest — an
image this run published — so Pipemesh jobs can consume it by key
([DESIGN-V59 §7](https://pipemesh.io/docs)); or, with `place: true`,
says where in Pipemesh's registry to push it.

```yaml
# pipemesh.yaml
release:
  produces: { image: oci }
  delegate: { type: github_actions, params: { workflow: release.yml } }
deploy:
  consumes: [release/image]
```

```yaml
# .github/workflows/release.yml (after pushing the image)
- uses: pipemesh/produce@v1
  with:
    key: image
    type: oci
    ref: ghcr.io/acme/app
    digest: ${{ steps.push.outputs.digest }}
```

The entry is verified here (docker or crane) and uploaded as the
`pipemesh-produces-<key>` artifact; a file entry needs no action — upload
an artifact named after its key.

## Pushing into Pipemesh's registry

With `place: true`, the action emits nothing and outputs `ref`, where
this run pushes the key's image in Pipemesh's registry:
`<registry>/<repository>:<tag>`, the key's place (a pull request's run
has its own) under the job run's own tag (DESIGN-V142 §3). When the run
succeeds, Pipemesh records the image the registry holds there under that
tag, with its digest; a key the run neither pushed nor emitted fails the
job.

```yaml
# pipemesh.yaml
bundle:
  job_type: build
  consumes: { APP: build/app_image }
  produces: { bundle_image: oci }
  github_actions: bundle.yml
```

```yaml
# .github/workflows/bundle.yml
permissions: { id-token: write, contents: read }
steps:
  - uses: pipemesh/consume@v1
    with:
      registry-login: true       # docker login: pull what it consumes, push to its places
  - id: place
    uses: pipemesh/produce@v1
    with:
      key: bundle_image
      place: true
  - run: |
      docker build --build-arg BASE="$APP" -t "${{ steps.place.outputs.ref }}" .
      docker push "${{ steps.place.outputs.ref }}"
```

- **The run proves itself** with its own GitHub OIDC token, as
  `pipemesh/consume` does: the job needs `id-token: write`, and
  `pipemesh-url` names the instance (default `https://pipemesh.io`).
- **The push needs a login:** `pipemesh/consume` with `registry-login:
  true` gives one. Jib, crane and ko push there as well as docker:
  `./gradlew jib -Djib.to.image="${{ steps.place.outputs.ref }}"`.
- **A key with `type: oci` only;** a file entry is an uploaded artifact
  named after its key.
