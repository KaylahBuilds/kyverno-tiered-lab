# Tier 3 — Govern owners, image references, and trust

The default policy enforces two checks in `kyverno-lab-tier3`: an owner from the lab's approved list and an image reference matching an exact registry, approved repository prefix, and complete SHA-256 digest syntax. Both app containers and optional init/ephemeral containers are examined.

```sh
.tools/kyverno test tier-3-governance --detailed-results
```

This uses the Linux installer from the root README. If you installed the pinned CLI on your PATH instead, substitute `kyverno` for `.tools/kyverno`.

Approved teams are `platform` and `applications`. Allowed references use a single image-name component beneath either of those prefixes at `registry.example.invalid`. This intentionally reserved hostname and the all-zero digest are **synthetic**, not a real image or a verified hash.

| Fixture | Expected outcome |
| --- | --- |
| `approved` | pass |
| `unapproved-team`, `missing-team` | fail |
| `mutable-tag`, `short-digest` | fail |
| `wrong-registry`, `registry-lookalike`, `unapproved-prefix` | fail |
| `unsafe-init-image` | fail |
| `outside-scope` | skip |

These ten outcomes test local reference and ownership rules only. The anchored registry expression rejects a lookalike hostname; digest syntax excludes tags. Neither proves the referenced image exists, that its contents are safe, or that an approved builder produced it. Approved labels are claims, not an authorization system.

## Extend from reference checks to verified trust

[image-trust.yaml.example](../examples/image-trust.yaml.example) is an **inactive, unvalidated signature-verification skeleton** for the current ImageValidatingPolicy API. The default lab neither applies it nor contacts a registry.

Before activating a reviewed derivative:

1. Supply a real repository scope, an exact signer identity, an exact OIDC issuer, and the approved trust root/log configuration for your signing system. Use no wildcard workflow identity as an approval shortcut.
2. Pair image verification with an independently enforced registry/repository allowlist. Images outside a verification policy's match scope must not become a bypass.
3. Use real digest-pinned images and validate app, init, and ephemeral-container coverage. Decide on tag mutation separately; the template sets `mutateDigest: false`.
4. Test signed/approved, unsigned, wrong-signer, wrong-issuer, mutated-artifact, unavailable-registry, and expired/revoked-trust scenarios using the actual cluster and registry integration. Verify failure behavior and cache effects.
5. If provenance is required, add attestation verification **and** claims policy: subject digest, predicate type, builder identity, source repository, source revision, and allowed build process. A signature alone is not provenance and provenance alone does not mean safe code.
6. Review rollout, availability, authorization, and recovery with the cluster owners before a production installation.

This lab does not manufacture signatures or trusted attestations. It does not include a generic exception object or enable controller-wide exception settings. See [EXCEPTIONS.md](EXCEPTIONS.md) for a controlled lifecycle.

The learning progression is cumulative, but the namespaces are deliberately isolated: applying the Tier 3 policy does not install the Tier 2 hardening checks in Tier 3. Combine and test the intended control set when adapting the lab.
