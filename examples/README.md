# Examples

- Create a directory for each example.
- Create a `_header.md` file in each directory to describe the example.
- See the `default` example provided as a skeleton - this must remain, but you can add others.
- Run `avm pre-commit` from the repo root to format the examples and generate the required documentation.
- If you want an example to be ignored by the end to end pipeline add a `.e2eignore` file to the example directory.

> **Note:** Examples must be deployable and idempotent. Ensure that no input variables are required to run the example and that random values are used to ensure unique resource names. Supporting Azure resources in examples use the `Azure/azapi` provider.
