### Changed

- `Workflows/HOTFIX.md` (0.0.12) Step 1 is now titled "Hotfix plan and Director authorization", and its Actor names the Main Agent, who plans the hotfix, and the Technical Lead, who runs the Plan Review when one is required, beside the Director. The Actors table lists the Main Agent. The gate sentence "No hotfix work begins without this authorization." is unchanged, and `Registry/workflows.yml` copies the new title (#335)
- The hotfix plan may propose the maximum acceptable time to resolution; the Director approves it or states another, in the same decision that authorizes the hotfix and approves its plan (#335)
- A hotfix plan revised after the Director's answer goes back through the Technical Lead's Plan Review when the revision changes its risk tier or its Work Units and the revised plan carries a Medium-or-higher action; any other revision is presented again, with the earlier Plan Review record when the plan had one (#335)
- `Examples/HOTFIX_CHAIN_EXAMPLE.md`'s RISK line records the decision as "Step 1 authorization and plan approval", the gate as it now reads (#335)
