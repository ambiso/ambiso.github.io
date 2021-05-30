+++
title = "Generating Adversarial Examples - Challenge Writeup"
[taxonomies]
categories = ["writeup", "machinelearning"]
+++

"Jodlgang" is a challenge at the 2018 FAUST CTF.

From the challenge description:

> The Jodlgang platfrom replaced the old password login for a state-of-the-art face authentication system. To sign in, a patron must provide an image of his face alongside his email address. The face snap must be a color image of size 224x224 pixels and must not be larger than 1MB.

Luckily we are given the neural network architecture and its weight that are used to recognize faces.
This means we can use backpropagation to generate an image that look like a desired person - at least to the neural network.

More in the [presentation](./faustctf-2018-jodlgang.pdf) I made on this challenge.
