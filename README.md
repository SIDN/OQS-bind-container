# OQS-bind with Falcon, MAYO, SQISign and SNOVA support, packaged in a container

This repository contains the scripts to build a container with SIDN Labs' [OQS-bind](https://github.com/SIDN/OQS-bind), which is a fork of deSEC's and Jason Goertzen's OQS-bind.
Our fork supports the Falcon-512, MAYO-2, SQISign-1, SNOVA2454 and SNOVA37172 post-quantum algorithms.

## Building the image

To build the image, run this (simplified) command:

	podman build -f Dockerfile --tag=pqc-bind-oqs:latest

The tag is an example, just make sure you can find the image again for running the image as container.

## Building for distribution

Be sure to use the correct bind-oqs version and check the patches/ directory for the corresponding patch.

To build the image for distribution on multiple platforms, make sure that you have `qemu-user-static` installed, then run the following commands:

	podman build --platform linux/amd64,linux/arm64 -f Dockerfile --manifest=ghcr.io/sidn/oqs-bind-container:v4

To distribute this container to Github, we do the following steps.
First, Obtain a personal access token

	export CR_PAT=YOUR_TOKEN

And login to Github using this token

	echo $CR_PAT | podman login ghcr.io -u USERNAME --password-stdin
	> Login Succeeded

Then, push the images:

	podman push ghcr.io/sidn/oqs-bind-container:v4
	podman push ghcr.io/sidn/oqs-bind-container:v4 ghcr.io/sidn/oqs-bind-container:latest

Note: before pushing the `latest` tag, make sure to double-check that everything works.
