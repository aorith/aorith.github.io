---
title: "Secrets Management With SOPS and age"
date: "2023-10-22T19:12:27+02:00"
draft: false
tags:
  - cloud
  - terraform
---

> I wonder if in the future we'll see a spike in job offers for roles like 'Expert in migrations from AWS to $NEW_FANCY_CLOUD'

If there is something that I dislike about the current state of the art of infraestructure deployment, it would be the immense vendor lock-in that we have today with the major cloud providers.

Cloud providers aim to offer a wide range of services, from container registries and DNS to message queues and storage. However, there's one aspect I prefer to keep away from the cloud, and that's secrets management. While it's not always possible to do so, as some applications are tightly integrated with a specific cloud, I try to maintain this separation whenever possible, provided my `$DAYJOB` allows for it of course.

I don't avoid it, some project secrets are better managed in the cloud, but if the project can avoid this vendor lock-in an alternative is always welcome.

## SOPS and age

Introducing two powerful tools, [SOPS](https://github.com/getsops/sops) (Secrets OPerationS) and [age](https://github.com/FiloSottile/age), for secure secrets management.

**SOPS** is an editor of encrypted files, it supports AWS KMS, GCP KMS, Azure Key Vault, and more. But hold on a second, weren't we trying to keep our secrets separate from the cloud? Don't worry, SOPS also extends its support to `age` and PGP.

Now, let's explore how to combine the capabilities of both these tools with Terraform.

## Encryption Key

To begin, let's generate an encryption key file using `age-keygen`.

```sh
$ age-keygen -o key.txt
Public key: age1hy5qdudcg4rcqg0s3x07mq53jsep38yjjrl0zkxe73m99w008pkqyh3ct7
$ ls -l
total 4
-rw------- 1 aorith wheel 189 Oct 22 18:56 key.txt
```

Now, let's test it using `age` exclusively.

```sh
$ echo 'mysecret' > file.txt
$ cat file.txt | age -r age1hy5qdudcg4rcqg0s3x07mq53jsep38yjjrl0zkxe73m99w008pkqyh3ct7 -o file.txt.age

$ strings file.txt.age
age-encryption.org/v1
-> X25519 pEI1zgh26Tffu8l/WGFWA8pTc1yQrAhMpGTvr4yp+Xc
5xnGQV/FGIiM7lFKXkMnlHbTH5ltkPcDUclPGjsye6I
--- cU8mLsmKFVMQwS8Ml7YVVZMVLkuBkUAHcfFmNJzsLSM

$ file file.txt.age
file.txt.age: data

$ age --decrypt -i key.txt file.txt.age
mysecret
```

As you can see, the file is encrypted and decrypted successfully, as a recipient (the public keys that can decrypt the encrypted files) you can use the public key that age generated or an SSH public key. Multiple recipients are also allowed.

## SOPS & age

Imagine that you have a `secrets.json` file in our project with the following content.

```json
{
  "username": "jon",
  "password": "super-secret-password"
}
```

You can encrypt it using SOPS.

```sh
$ sops --encrypt --age age1hy5qdudcg4rcqg0s3x07mq53jsep38yjjrl0zkxe73m99w008pkqyh3ct7 secrets.json > secrets.enc.json
```

Here's the resulting encrypted file.

```json
{
  "username": "ENC[AES256_GCM,data:+FeM,iv:JYpoOS5rj4mUtlEg5t0B8CdCfJqS41jgY3lLnB1OXww=,tag:fe6zZwWU/d7A81vIISgxeg==,type:str]",
  "password": "ENC[AES256_GCM,data:B05fVImpohAyOFK3IH5gknaAs4x2,iv:49GuMJ3WWN3PkCUMP96W/oJMNB3Bmt+yisr8v0Mx7ho=,tag:6YaqEsA8uz+MN9tNisXiXw==,type:str]",
  "sops": {
    "kms": null,
    "gcp_kms": null,
    "azure_kv": null,
    "hc_vault": null,
    "age": [
      {
        "recipient": "age1hy5qdudcg4rcqg0s3x07mq53jsep38yjjrl0zkxe73m99w008pkqyh3ct7",
        "enc": "-----BEGIN AGE ENCRYPTED FILE-----\nYWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IFgyNTUxOSBUK0RnMlNzWEZPWTh2RGJN\nQ0JuS1ROLzJxUDlZZ3JxWVVLbG1oT1VuNkdZClpKeEZLd3ZybWNnVXJzOVNGTnJq\nVjZrSUFnY3A5SUVERjc4OGR6d01neFkKLS0tIG54dlVQeFhrbmo1SWpSRlVzZmlu\nLzhObkhnWUh4Z3VIbXFtemlkZ294dEEK0pdtl7corDpekmpH0uKNEYvvEFL+gbJb\nvp+lV21yEaMrgACfwqpPAxHWpwfPbaQsvsd6lx2sQGxu8Pbq2xJQyg==\n-----END AGE ENCRYPTED FILE-----\n"
      }
    ],
    "lastmodified": "2023-10-22T17:06:41Z",
    "mac": "ENC[AES256_GCM,data:heZ8JWHCxEwNrElet4pxbLPVdr6LYfTbmwJskU3vTI93nWzkWheeGFWK7N/0AWLhwnym8JwTCyILyaBH8awhd97OkF4mxnof7qcmdVDp03ym0UfAexUzetoHRQCwgWrqy6aptIJkBrz09zU1AcKKkSVXQlliXAm4LlXLRoko/jo=,iv:8Vn3xekdgdwOVlPLc/ZyaYdrORPLLrAUnFyY09NtnNc=,tag:A6S73GmysHfY/HN439wpCg==,type:str]",
    "pgp": null,
    "unencrypted_suffix": "_unencrypted",
    "version": "3.8.1"
  }
}
```

As you can see, the file contains an array of `age` recipients who can decrypt it.

## Terraform Integration

Integrating SOPS with Terraform is a straightforward process. For this example, I'll use a slightly modified version of the one available in the [SOPS provider documentation](https://registry.terraform.io/providers/carlpett/sops/latest/docs).

```terraform
# main.tf
terraform {
  required_providers {
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.0"
    }
  }
}

provider "sops" {}

data "sops_file" "secrets-file" {
  source_file = "secrets.enc.json"
}

output "password" {
  value     = data.sops_file.secrets-file.data["password"]
  sensitive = true
}
```

The SOPS provider needs an environment variable to know where is the private `age` key.
All we need to do is export the location of the private `age` key.

```sh
$ export SOPS_AGE_KEY_FILE="$PWD/key.txt"
```

Now, let's run Terraform to ensure it correctly decrypts the secrets.

```sh
$ terraform init
$ terraform apply

data.sops_file.secrets-file: Reading...
data.sops_file.secrets-file: Read complete after 0s [id=-]

Changes to Outputs:
  + password = (sensitive value)

You can apply this plan to save these new output values to the Terraform state, without changing any real infrastructure.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes


Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

password = <sensitive>
```

Terraform is smart enough to notice that the output and the **state** will contain sensitive data and takes measures to avoid leaking it.

We can peek at the Terraform `state` to confirm that the password really is there.

```sh
$ strings terraform.tfstate | grep -Eo '"password": ".*"'
"password": "super-secret-password"
```

With this seamless integration you can use SOPS and `age` together with Terraform to manage your secrets. Always remember not to commit files that contain or might contain sensitive information, such as the Terraform state file or even `.tfvars` files.
