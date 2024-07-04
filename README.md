# terraform-output-parser

## Why?
Sometimes I use Terraform to deploy helm releases, using the [Helm Provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs) for Terraform.

Although it works fine, it still have some room for improvement (ex: [this issue](https://github.com/hashicorp/terraform-provider-helm/issues/1121)).

Thinking about this specific issue and tired of spamming my console with a bunch of lines because of it, I wrote this simple wrapper that parses my output giving me fewer lines and better diffs.
It detects `helm_release` blocks and:
- hide metadata values
- better diff values


## Known bugs

- Terraform asks for approval before each apply. As the prompt is made in the middle of the line, the wrapper only prints the prompt after you type yes/no
- Terraform console does not work
- Diff logic is broken, so it does not show any diff when creating/destroying releases. (probably a `-N` should fix)
