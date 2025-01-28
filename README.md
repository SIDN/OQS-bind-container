# Bind 9 nameserver oqs support for Falcon and Mayo

This repository contains the scripts to build bind DNS server with support for the Falcon quantum-safe algorithm.

## Building the image

To build the image, run this (simplified) command:

	podman build -f Dockerfile --tag=pqc-bind-oqs:latest

The tag is an example, just make sure you can find the image again for running the image as container.

## Building for distribution

Be sure to use the correct bind-oqs version and check the patches/ directory for the corresponding patch.

To build the image for distribution, run the following commands:

	podman build --platform linux/amd64,linux/arm64 -f Dockerfile --tag=pqc-bind-oqs:latest
	# podman push

Optionally, we can publish it to a container registry, but that is future work for now.
