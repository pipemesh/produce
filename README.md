# pipemesh/output

Emits an entry of the dispatching PipeMesh job's output manifest — an
image or a package this run published — so PipeMesh jobs can consume it
by key ([DESIGN-V59 §7](https://pipemesh.dev/docs)).

```yaml
# pipemesh.yaml
release:
  outputs: { image: oci }
  delegate: { type: github_actions, params: { workflow: release.yml } }
deploy:
  consumes: [release/image]
```

```yaml
# .github/workflows/release.yml (after pushing the image)
- uses: pipemesh/output@v1
  with:
    key: image
    type: oci
    ref: ghcr.io/acme/app
    digest: ${{ steps.push.outputs.digest }}
```

The entry is verified here (docker or crane for `oci`, `npm view` for
`npm`) and uploaded as the `pipemesh-outputs-<key>` artifact; a file entry
needs no action — upload an artifact named after its key.
