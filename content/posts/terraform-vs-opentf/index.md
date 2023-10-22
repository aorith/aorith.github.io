---
title: "Terraform vs OpenTF"
date: "2023-10-22T16:24:28+02:00"
draft: false
tags:
  - terraform
  - thoughts
---

As a Linux enthusiast and supporter of free software, you'd think I'd be thrilled about [OpenTF](https://opentofu.org/) or OpenTofu (what a name…), an open-source _fork_ of [Terraform](https://www.terraform.io/), community-driven and managed by the Linux Foundation. However, I find myself harboring some conflicting opinions on the matter.

## Terraform's Origin

Terraform was originally developed by [Mitchell Hashimoto](https://mitchellh.com/) and his team. If you don't know Mitchell, he is a talented developer based in Los Angeles who happens to use NixOS within a VM as his main dev environment. He is currently developing [Ghostty](https://mitchellh.com/ghostty), a terminal emulator I'm excited to try.

## The Rise of Terraform

But back to the main point, when Terraform first emerged, their team put in commendable efforts to make it accessible to the masses. It was, and still is, a fantastic open-source tool that resolved many Infrastructure as Code (IaC) needs.

I said "to make it accessible", but they really pushed it. Terraform garnered widespread adoption, and the folks at [HashiCorp](https://www.hashicorp.com/) did a splendid job of keeping the tool well-documented and building a rich ecosystem of plugins and providers. Not to mention the great community that emerged around Terraform.

![Terraform Google Search Trend](tf-trends.png "Google search trends for Terraform since its inception")

## The Need for Sustainable Revenue

Every company needs to sustain itself, and HashiCorp found its way by introducing Terraform Cloud. It's not mandatory for using Terraform, but it provides a convenient platform to manage projects, secrets, and state.

Before long, other companies saw the potential in leveraging Terraform for their profit, leading to the emergence of various "Terraform Clouds" and other services, some of them with more competitive pricing. HashiCorp surely noticed a dip in their revenue due to this competition.

## HashiCorp Measures

In response, this August, HashiCorp decided to change Terraform's license from MPL 2.0 to a BSL (Business Source License). You can read the announcement [here](https://www.hashicorp.com/blog/hashicorp-adopts-business-source-license). The BSL license remains open-source but protects HashiCorp against companies looking to exploit their product.

## My Perspective

As you might have guessed, I lean towards HashiCorp's stance. If you check the [OpenTofu manifesto](https://opentofu.org/manifesto), particularly the [supporters](https://opentofu.org/supporters/) section, you'll notice that many of the companies there were profiting from services around Terraform.

It's essential to emphasize that Terraform remains entirely free to use as an IaC tool for administrators, developers, companies and the like. The only restriction is making a profit by creating products that directly compete with Terraform Cloud. Here's the [license FAQ](https://www.hashicorp.com/license-faq) that explains it better than I do.

My perspective on this matter may change over time, and I deeply respect companies that are trying to build profitable products around Terraform, especially when they've contributed to the code. However, for the time being, I don't think that this is good for OSS, even if it might appear contradictory.

I'm curious to hear your thoughts on this.
